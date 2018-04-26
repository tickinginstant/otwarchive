require 'spec_helper'

describe PotentialMatch do

  describe "when generating potential matches" do
    let(:settings) { PotentialMatchSettings.create }
    let(:challenge) do
      create(:gift_exchange, potential_match_settings: settings)
    end
    let(:collection) { create(:collection, challenge: challenge) }

    let!(:signup1) { create(:challenge_signup, collection_id: collection.id) }
    let!(:signup2) { create(:challenge_signup, collection_id: collection.id) }

    it "should handle errors gracefully" do
      allow(PotentialMatch).to receive(:new).and_raise
      PotentialMatch.generate(collection)
      expect(PotentialMatch.errored?(collection)).to be_truthy
      expect(ChallengeAssignment.errored?(collection)).to be_falsey
      expect(collection.potential_matches.count).to eq 0
      expect(collection.assignments.count).to eq 0
    end
  end

  before do
    @potential_match = create(:potential_match)
    @collection = @potential_match.collection
    @first_signup = @collection.signups.first
    @last_signup = @collection.signups.last
  end

  it "should have a progress key" do
    expect(PotentialMatch.progress_key(@collection)).to include("#{@collection.id}")
  end
  
  it "should have a signup key" do
    expect(PotentialMatch.signup_key(@collection)).to include("#{@collection.id}")
  end

  describe "when matches are being generated" do
    before do
      PotentialMatch.set_up_generating(@collection)
    end
  
    it "should report progress" do 
      expect(PotentialMatch.in_progress?(@collection)).to be_truthy
      expect(PotentialMatch.progress(@collection)).to be == "0.0"
    end
  end
end
