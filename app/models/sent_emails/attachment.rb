# frozen_string_literal: true

require "digest"

module SentEmails
  class Attachment < ApplicationRecord
    self.table_name = "sent_emails_attachments"

    belongs_to :email

    validates :filename, presence: true

    scope :inline_attachments, -> { where(inline: true) }
    scope :regular_attachments, -> { where(inline: [false, nil]) }
    scope :with_blob, -> { where.not(blob: nil) }

    # Check if this is an inline/CID attachment
    def inline?
      inline == true || content_id.present?
    end

    # Get base64 data URL for embedding in HTML
    # If this attachment doesn't have a blob, try to find one with the same hash
    def data_url
      blob_data = blob || find_shared_blob
      return nil unless blob_data.present? && content_type.present?
      "data:#{content_type};base64,#{Base64.strict_encode64(blob_data)}"
    end

    # Calculate content hash for deduplication
    def self.calculate_hash(content)
      Digest::SHA256.hexdigest(content)
    end

    # Find an existing attachment with the same content hash that has a blob
    def find_shared_blob
      return nil unless content_hash.present?
      Attachment.where(content_hash: content_hash).where.not(blob: nil).first&.blob
    end

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
