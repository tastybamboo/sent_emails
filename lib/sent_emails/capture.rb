# frozen_string_literal: true

module SentEmails
  class Capture
    SENSITIVE_SETTINGS_KEYS = %i[password user_name api_key secret access_key].freeze
    SAFE_SETTINGS_KEYS = %i[address port domain authentication enable_starttls_auto openssl_verify_mode].freeze

    def self.call(**args)
      new(**args).call
    end

    def initialize(message:, mailer:, action:, params:, delivery_method:, delivery_settings:, delivery_type: nil, request: nil, status: :sent)
      @message = message
      @mailer = mailer
      @action = action
      @params = params
      @delivery_method = delivery_method
      @delivery_settings = delivery_settings
      @delivery_type = delivery_type
      @request = request
      @status = status
    end

    def call
      email = Email.create!(
        message_id: @message.message_id,

        # Rails context
        mailer: @mailer,
        action: @action,
        template_path: derive_template_path,
        mailer_params: serialize_params,

        # Delivery mechanism
        delivery_method: @delivery_method.to_s,
        provider: detect_provider,
        delivery_settings: sanitize_delivery_settings,

        # Email content
        from_address: extract_from,
        to_addresses: extract_to,
        cc_addresses: extract_cc,
        bcc_addresses: extract_bcc,
        subject: @message.subject,
        text_body: extract_text_body,
        html_body: extract_html_body,
        headers: extract_headers,

        # Environment and context
        environment: Rails.env,
        delivery_type: @delivery_type,
        process_type: detect_process_type,
        request_id: extract_request_id,
        user_agent: extract_user_agent,
        remote_ip: extract_remote_ip,
        ruby_version: RUBY_VERSION,
        rails_version: Rails::VERSION::STRING,
        context: build_context,

        status: @status,
        sent_at: @status == :sent ? Time.current : nil
      )

      capture_attachments(email)
      create_initial_event(email)
      email
    end

    private

    def create_initial_event(email)
      email.events.create!(
        event_type: @status.to_s,
        provider: nil,
        occurred_at: Time.current,
        payload: {source: "rails", delivery_type: @delivery_type}
      )
    end

    def derive_template_path
      return nil unless @mailer && @action
      "#{@mailer.underscore}/#{@action}"
    end

    def detect_provider
      case @delivery_method.to_sym
      when :mailpace then "mailpace"
      when :postmark then "postmark"
      when :sendgrid then "sendgrid"
      when :ses then "ses"
      when :smtp
        detect_provider_from_smtp_host
      when :test then "test"
      when :letter_opener then "letter_opener"
      else
        @delivery_method.to_s
      end
    end

    def detect_provider_from_smtp_host
      host = @delivery_settings[:address].to_s.downcase
      case host
      when /mailpace/ then "mailpace"
      when /sendgrid/ then "sendgrid"
      when /postmark|smtp\.postmarkapp/ then "postmark"
      when /amazonaws|ses/ then "ses"
      when /mailgun/ then "mailgun"
      when /sparkpost/ then "sparkpost"
      when /mandrill|mandrillapp/ then "mandrill"
      else "smtp"
      end
    end

    def sanitize_delivery_settings
      return {} unless @delivery_settings.is_a?(Hash)

      @delivery_settings
        .slice(*SAFE_SETTINGS_KEYS)
        .transform_values(&:to_s)
    end

    def serialize_params
      return {} unless @params.respond_to?(:to_h)

      # Only serialize simple values, skip complex objects
      @params.to_h.transform_values do |value|
        case value
        when String, Numeric, TrueClass, FalseClass, NilClass
          value
        when Symbol
          value.to_s
        when Hash
          value.transform_values { |v| serializable_value(v) }
        when Array
          value.map { |v| serializable_value(v) }
        else
          # For ActiveRecord models, store class name and ID
          if value.respond_to?(:id) && value.respond_to?(:class)
            {_class: value.class.name, _id: value.id}
          else
            value.to_s
          end
        end
      end
    rescue
      {}
    end

    def serializable_value(value)
      case value
      when String, Numeric, TrueClass, FalseClass, NilClass
        value
      else
        value.to_s
      end
    end

    def extract_from
      # Get formatted "Name <email>" if available, otherwise just the email
      from_header = @message[:from]
      if from_header&.formatted&.first.present?
        from_header.formatted.first
      else
        @message.from&.first || "unknown"
      end
    end

    def extract_to
      extract_formatted_addresses(:to)
    end

    def extract_cc
      extract_formatted_addresses(:cc)
    end

    def extract_bcc
      extract_formatted_addresses(:bcc)
    end

    def extract_formatted_addresses(field)
      header = @message[field]
      return [] unless header

      if header.formatted.present?
        header.formatted
      else
        Array(@message.public_send(field))
      end
    end

    def extract_text_body
      if @message.multipart?
        @message.text_part&.decoded
      elsif !@message.content_type&.include?("html")
        @message.body.decoded
      end
    rescue => e
      Rails.logger.warn("[SentEmails] Failed to extract text body: #{e.message}")
      nil
    end

    def extract_html_body
      if @message.multipart?
        @message.html_part&.decoded
      elsif @message.content_type&.include?("html")
        @message.body.decoded
      end
    rescue => e
      Rails.logger.warn("[SentEmails] Failed to extract HTML body: #{e.message}")
      nil
    end

    def extract_headers
      # Skip headers that are already stored in dedicated columns
      skip_headers = %w[From To Cc Bcc Subject Date Message-ID MIME-Version Content-Type Content-Transfer-Encoding]

      headers = {}
      @message.header.fields.each do |field|
        next if skip_headers.include?(field.name)

        # For address headers, format as "Name <email>" if possible
        value = if field.respond_to?(:formatted) && field.formatted.present?
          field.formatted.is_a?(Array) ? field.formatted.first : field.formatted
        elsif field.respond_to?(:addresses) && field.addresses.present?
          field.addresses.first
        else
          field.value.to_s
        end

        headers[field.name] = value if value.present?
      end
      headers
    end

    def capture_attachments(email)
      return unless @message.attachments.any?

      storage_strategy = SentEmails.configuration.attachment_storage
      max_size = SentEmails.configuration.max_attachment_size

      @message.attachments.each do |attachment|
        # Check if this is an inline/CID attachment
        content_id = attachment.content_id&.gsub(/[<>]/, "")
        is_inline = attachment.content_disposition&.start_with?("inline") || content_id.present?

        decoded_body = attachment.body.decoded
        content_hash = Attachment.calculate_hash(decoded_body)

        attrs = {
          filename: attachment.filename,
          content_type: attachment.content_type,
          byte_size: decoded_body.bytesize,
          content_id: content_id,
          inline: is_inline,
          content_hash: content_hash
        }

        # Store blob based on strategy and size, but deduplicate
        if storage_strategy == :database && attrs[:byte_size] <= max_size
          # Check if we already have this content stored
          existing_blob = Attachment.where(content_hash: content_hash).where.not(blob: nil).exists?

          # Only store blob if no existing attachment has it
          unless existing_blob
            attrs[:blob] = decoded_body
          end
        end

        email.attachments.create!(attrs)
      end
    end

    def detect_process_type
      return "job" if defined?(Sidekiq) && Sidekiq.server?
      return "job" if defined?(Delayed) && ENV["DELAYED_JOB"] == "true"
      return "web" if defined?(ActionDispatch::Request)
      return "console" if defined?(IRB) || $0.include?("irb")
      return "runner" if $0.include?("rails") && ARGV.first == "runner"
      "unknown"
    end

    def extract_request_id
      return nil unless @request
      @request.request_id
    rescue
      nil
    end

    def extract_user_agent
      return nil unless @request
      @request.user_agent
    rescue
      nil
    end

    def extract_remote_ip
      return nil unless @request
      @request.remote_ip
    rescue
      nil
    end

    def build_context
      context = {}
      
      if @request
        context[:request] = {
          method: @request.method,
          path: @request.path,
          host: @request.host,
          port: @request.port
        }
      end

      context[:current_user_id] = extract_current_user if defined?(current_user)
      context
    end

    def extract_current_user
      return nil unless defined?(current_user)
      current_user&.id rescue nil
    end
  end
end
