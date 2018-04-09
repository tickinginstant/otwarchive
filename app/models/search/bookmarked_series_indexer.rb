class BookmarkedSeriesIndexer < BookmarkableIndexer
  def self.klass
    "Series"
  end

  def self.klass_with_includes
    Series.includes(:works,
                    works_for_search: [:tags, :filters, :direct_filters],
                    pseuds: [:user])
  end
end
