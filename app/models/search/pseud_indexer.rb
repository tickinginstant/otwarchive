class PseudIndexer < Indexer

  def self.klass
    "Pseud"
  end

  def self.klass_with_includes
    Pseud.includes(:user, :collections)
  end

  def self.mapping
    {
      pseud: {
        properties: {
          name: {
            type: "text",
            analyzer: "simple"
          },
          # adding extra name field for sorting
          sortable_name: {
            type: "keyword"
          },
          byline: {
            type: "text",
            analyzer: "standard"
          },
          user_login: {
            type: "text",
            analyzer: "simple"
          },
          fandom: {
            type: "nested"
          }
        }
      }
    }
  end

  def document(object)
    object.as_json(
      root: false,
      only: [:id, :user_id, :name, :description, :created_at],
      methods: [
        :user_login,
        :byline,
        :collection_ids
      ]
    ).merge(extras(object).as_json)
  end

  def extras(pseud)
    info = [
      work_counts(pseud),
      bookmark_counts(pseud),
      fandoms(pseud),
      { sortable_name: pseud.name.downcase }
    ]

    info.reduce(&:merge)
  end

  private

  # Given the ID of a pseud, ensure that this ID is included in all of the data
  # loaded in batches. If the passed-in ID isn't included, wipes all data
  # already loaded, so that it will be forced to recompute with the new ID
  # included.
  def ensure_included(id)
    unless batch_set.include?(id)
      batch_set << id
      @tag_info = nil
      @bookmark_counts = nil
      @work_counts = nil
    end
  end

  # The set of IDs that we should load batch information about.
  def batch_set
    @batch_set ||= Set.new(ids)
  end

  # Helper function that takes the set of IDs returned by batch_set and
  # converts it to an array (for better Rails compatibility).
  def batch_ids
    batch_set.to_a
  end

  # Returns a hash to be combined in extras that maps from fandoms to a list of
  # the form:
  #   [
  #     { id: 1, name: "Star Trek", count: 5 },
  #     { id_for_public: 1, name: "Star Trek", count: 4 }
  #   ]
  def fandoms(pseud)
    public_fandoms = tag_info(pseud, "Fandom", false).map do |info|
      # The public fandoms list has all of the "id" keys transformed into
      # "id_for_public" instead.
      info.transform_keys! { |key| key == :id ? :id_for_public : key }
    end

    registered_fandoms = tag_info(pseud, "Fandom", true)

    {
      fandoms: public_fandoms + registered_fandoms
    }
  end

  # Produces an array of hashes with the format.
  # [{ id: 1, name: "Star Trek", count: 5 }]
  # Includes restricted works only if the include_restricted setting is
  # enabled. Because we load information in bulk, this will take SIGNIFICANTLY
  # longer when called on pseuds outside of the batch.
  def tag_info(pseud, tag_type, include_restricted)
    ensure_included(pseud.id)

    if @tag_info.nil? || @tag_info[tag_type].nil?
      load_tag_info(tag_type)
    end

    counts = {}
    names = {}

    info = @tag_info[tag_type][pseud.id] || []
    info.each do |tag_id, tag_name, restricted, count|
      next if restricted && !include_restricted
      counts[tag_id] ||= 0
      counts[tag_id] += count
      names[tag_id] = tag_name
    end

    counts.keys.map { |id| { id: id, name: names[id], count: counts[id] } }
  end

  # Load information about tags for all pseud IDs in this batch.
  # Loads info in bulk to reduce N+1 errors.
  def load_tag_info(tag_type)
    @tag_info ||= {}
    @tag_info[tag_type] ||= {}

    Work.where(countable_works_conditions).
      joins(:creatorships).where(creatorships: { pseud_id: batch_ids }).
      joins(:direct_filters).where(tags: { type: tag_type }).
      group("creatorships.pseud_id", "tags.id", "tags.name", "restricted").
      count.each_pair do |key, count|
      pseud_id, tag_id, tag_name, restricted = key
      @tag_info[tag_type][pseud_id] ||= []
      @tag_info[tag_type][pseud_id] << [tag_id, tag_name, restricted, count]
    end
  end

  # Return the bookmark counts for the given pseud.
  # Because we load information in bulk, this will take SIGNIFICANTLY longer
  # when called on pseuds outside of the batch.
  def bookmark_counts(pseud)
    ensure_included(pseud.id)
    load_bookmark_counts if @bookmark_counts.nil?

    {
      public_bookmarks_count: @bookmark_counts[:public][pseud.id] || 0,
      general_bookmarks_count: @bookmark_counts[:general][pseud.id] || 0
    }
  end

  # The relation containing all bookmarks that should be included in the count
  # for logged-in users (when restricted to a particular pseud).
  def general_bookmarks
    @general_bookmarks ||=
      Bookmark.with_missing_bookmarkable.
      or(Bookmark.with_bookmarkable_visible_to_registered_user).
      is_public
  end

  # The relation containing all bookmarks that should be included in the count
  # for logged-out users (when restricted to a particular pseud).
  def public_bookmarks
    @public_bookmarks ||=
      Bookmark.with_missing_bookmarkable.
      or(Bookmark.with_bookmarkable_visible_to_all).
      is_public
  end

  # Load information about bookmark counts for all pseud IDs in this batch.
  # This operation is performed in bulk to try to minimize N+1 issues.
  def load_bookmark_counts
    @bookmark_counts ||= {
      public: public_bookmarks.where(
        pseud_id: batch_ids
      ).group(:pseud_id).count,
      general: general_bookmarks.where(
        pseud_id: batch_ids
      ).group(:pseud_id).count,
    }
  end

  # Return the work counts for the given pseud.
  # Because we load information in bulk, this will take SIGNIFICANTLY longer
  # when called on pseuds outside of the batch.
  def work_counts(pseud)
    ensure_included(pseud.id)
    load_work_counts if @work_counts.nil?

    restricted = @work_counts[[pseud.id, true]] || 0
    unrestricted = @work_counts[[pseud.id, false]] || 0

    {
      public_works_count: unrestricted,
      general_bookmarks_count: unrestricted + restricted
    }
  end

  # Load information about work counts for all pseud IDs in this batch.
  # This operation is performed in bulk to try to minimize N+1 issues.
  def load_work_counts
    @work_counts ||=
      Work.where(countable_works_conditions).
      joins(:creatorships).where(creatorships: { pseud_id: batch_ids }).
      group("creatorships.pseud_id", "works.restricted").count
  end

  def countable_works_conditions
    {
      posted: true,
      hidden_by_admin: false,
      in_anon_collection: false,
      in_unrevealed_collection: false
    }
  end
end
