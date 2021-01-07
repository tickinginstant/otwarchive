class UserNameNotBannedValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if value.blank?

    ArchiveConfig.BANNED_USER_NAMES.each do |banned|
      if banned.casecmp?(value)
        record.errors.add(attribute, :exclusion, attribute: attribute, value: value)
        break
      end
    end
  end
end
