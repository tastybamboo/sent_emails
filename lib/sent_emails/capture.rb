# frozen_string_literal: true

module SentEmails
  class Capture
    SENSITIVE_SETTINGS_KEYS = %i[password user_name api_key secret access_key].freeze
    SAFE_SETTINGS_KEYS = %i[address port domain authentication enable_starttls_auto openssl_verify_mode].freeze

    def self.call(**args)
      new(**args).call
    end

    def initialize(message:, mailer:, action:, params:, delivery_method:, delivery_settings:)
      @message = message
      @mailer = mailer
      @action = action
      @params = params
      @delivery_method = delivery_method
      @delivery_settings = delivery_settings
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

        status: :sent,
        sent_at: Time.current
      )

      capture_attachments(email)
      email
    end

    private

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
      @message.from&.first || @message[:from]&.to_s || "unknown"
    end

    def extract_to
      Array(@message.to)
    end

    def extract_cc
      Array(@message.cc)
    end

    def extract_bcc
      Array(@message.bcc)
    end

    def extract_text_body
      return nil unless @message.multipart?

      @message.text_part&.decoded
    rescue
      @message.body.decoded unless @message.content_type&.include?("html")
    end

    def extract_html_body
      return nil unless @message.multipart?

      @message.html_part&.decoded
    rescue
      @message.body.decoded if @message.content_type&.include?("html")
    end

    def extract_headers
      important_headers = %w[
        Reply-To
        List-Unsubscribe
        X-Mailer
        X-Priority
        Importance
      ]

      headers = {}
      important_headers.each do |name|
        value = @message[name]&.to_s
        headers[name] = value if value.present?
      end
      headers
    end

    def capture_attachments(email)
      return unless @message.attachments.any?

      storage_strategy = SentEmails.configuration.attachment_storage
      max_size = SentEmails.configuration.max_attachment_size

      @message.attachments.each do |attachment|
        attrs = {
          filename: attachment.filename,
          content_type: attachment.content_type,
          byte_size: attachment.body.decoded.bytesize
        }

        # Store blob based on strategy and size
        if storage_strategy == :database && attrs[:byte_size] <= max_size
          attrs[:blob] = attachment.body.decoded
        end

        email.attachments.create!(attrs)
      end
    end
  end
end
