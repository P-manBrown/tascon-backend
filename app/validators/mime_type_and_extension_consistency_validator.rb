class MimeTypeAndExtensionConsistencyValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, _value)
    return true unless record.send(attribute).attached?

    changes = record.attachment_changes[attribute.to_s]
    return true if changes.blank?

    file = changes.attachable
    extension = file.original_filename.split(".").last

    return unless Marcel::MimeType.for(file) != Marcel::MimeType.for(extension:)

    record.errors.add(attribute, "のファイル形式と拡張子が一致しません。")
  end
end
