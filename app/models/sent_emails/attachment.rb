# frozen_string_literal: true

module SentEmails
  class Attachment < ApplicationRecord
    self.table_name = "sent_emails_attachments"

    belongs_to :email

    validates :filename, presence: true

    # Human-readable file size
    def human_size
      return "Unknown" unless byte_size

      if byte_size < 1024
        "#{byte_size} B"
      elsif byte_size < 1024 * 1024
        "#{(byte_size / 1024.0).round(1)} KB"
      else
        "#{(byte_size / (1024.0 * 1024)).round(1)} MB"
      end
    end

    # Check if content is stored
    def content_stored?
      blob.present?
    end

    # File extension
    def extension
      File.extname(filename).delete_prefix(".")
    end

    # Icon class based on content type
    def icon_class
      case content_type
      when /image/
        "photo"
      when /pdf/
        "document"
      when /spreadsheet|excel|csv/
        "table-cells"
      when /text/
        "document-text"
      else
        "paper-clip"
      end
    end
  end
end
