# frozen_string_literal: true

module SentEmails
  class EmailsController < ApplicationController
    layout "sent_emails/layouts/sent_emails"

    before_action :set_email, only: [:show, :destroy, :resend]

    def index
      @emails = Email.recent.with_events

      if params[:status].present?
        @emails = @emails.by_status(params[:status])
      end

      if params[:q].present?
        @emails = @emails.search(params[:q])
      end

      # Simple pagination without gem dependency
      @emails = paginate(@emails, per_page: 25)
    end

    def show
      @email = @email.includes(:events, :attachments)
      @events = @email.events.reverse_chronological
      @attachments = @email.attachments
    end

    def destroy
      @email.destroy!
      redirect_to emails_path, notice: "Email deleted successfully."
    end

    def resend
      # Find the original mailer and resend
      if @email.mailer.present? && @email.action.present?
        mailer_class = @email.mailer.constantize
        mailer_params = @email.mailer_params.symbolize_keys

        if mailer_params.any?
          mailer_class.with(**mailer_params).send(@email.action).deliver_later
        else
          mailer_class.send(@email.action).deliver_later
        end

        redirect_to email_path(@email), notice: "Email queued for resend."
      else
        redirect_to email_path(@email), alert: "Unable to resend: missing mailer information."
      end
    rescue => e
      redirect_to email_path(@email), alert: "Failed to resend: #{e.message}"
    end

    private

    def set_email
      @email = Email.find(params[:id])
    end

    def paginate(scope, per_page: 25)
      page = [params[:page].to_i, 1].max
      offset = (page - 1) * per_page
      
      # Fetch one extra record to detect if there are more pages without a COUNT query
      records = scope.offset(offset).limit(per_page + 1).load
      
      has_more = records.size > per_page
      records = records.first(per_page) if has_more
      
      # Add pagination methods to the result
      records.define_singleton_method(:current_page) { page }
      records.define_singleton_method(:has_more) { has_more }
      
      records
    end
  end
end
