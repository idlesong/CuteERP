# Shared behaviour for models with a PDF/image document attachment
# (replaces the old paperclip `has_attached_file :document`).
module DocumentAttachment
  extend ActiveSupport::Concern

  ALLOWED_CONTENT_TYPES = %w(
    image/jpeg image/jpg image/png application/pdf application/msword
    application/vnd.openxmlformats-officedocument.wordprocessingml.document
  ).freeze

  included do
    has_one_attached :document
    validate :document_content_type, if: -> { document.attached? }
    before_destroy :purge_document
  end

  private

  def document_content_type
    return if ALLOWED_CONTENT_TYPES.include?(document.blob.content_type)

    errors.add(:document, "content type must be JPEG/PNG/PDF/DOC/DOCX")
  end

  def purge_document
    document.purge_later if document.attached?
  end
end
