require 'spec_helper'

describe WorkIndexer do
  let(:fandom) { create(:canonical_fandom) }
  let(:synonym) { create(:fandom, merger: fandom) }
  let(:meta) { create(:canonical_fandom, sub_tag_string: fandom.name) }
  let(:collection) { create(:collection) }
  let(:relationship) { create(:canonical_relationship) }

  let(:work) do
    create(:work,
           posted: true, collections: [collection],
           fandom_string: "#{fandom.name}, #{synonym.name}, #{meta.name}",
           relationship_string: relationship.name)
  end

  describe "#index_documents" do
    it "doesn't perform a query on each object" do
      indexer = WorkIndexer.new([work.id])
      indexer.objects # load all of the objects

      # Make sure that there are no database queries beyond this point.
      expect_no_queries

      indexer.index_documents
    end
  end
end
