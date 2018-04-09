class BookmarkedExternalWorkIndexer < BookmarkableIndexer
  def self.klass
    "ExternalWork"
  end

  def self.klass_with_includes
    ExternalWork.includes(:tags, :filters, :direct_filters)
  end
end
