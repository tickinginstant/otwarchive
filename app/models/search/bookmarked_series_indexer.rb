class BookmarkedSeriesIndexer < BookmarkableIndexer
  def self.klass
    "Series"
  end

  def self.klass_with_includes
    Series.includes(:works,
                    public_works: [:tags, :filters, :direct_filters],
                    pseuds: [:user])
  end
end
