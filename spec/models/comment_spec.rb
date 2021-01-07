# frozen_string_literal: true

require "spec_helper"

describe Comment do
  context "with an existing comment from the same user" do
    let(:first_comment) { create(:comment) }

    let(:second_comment) do
      attributes = %w[pseud_id commentable_id commentable_type comment_content name email]
      Comment.new(first_comment.attributes.slice(*attributes))
    end

    it "should be invalid if exactly duplicated" do
      expect(second_comment.valid?).to be_falsy
      expect(second_comment.errors.keys).to include(:comment_content)
    end

    it "should not be invalid if in the process of being deleted" do
      second_comment.is_deleted = true
      expect(second_comment.valid?).to be_truthy
    end
  end

  describe "save" do
    context "when the name is banned" do
      before do
        allow(ArchiveConfig).to receive(:BANNED_USER_NAMES).and_return(["Admin"])
      end

      shared_examples "the name is banned" do
        it "generates an error" do
          expect(comment.save).to be_falsey
          expect(comment.errors.full_messages).to include("Name is reserved")
          expect(comment.new_record?).to be_truthy
        end
      end

      context "when the name exactly matches one of the banned user names" do
        let(:comment) { build(:comment, :by_guest, name: "Admin") }

        it_behaves_like "the name is banned"
      end

      context "when the name is a lowercase version of one of the banned user names" do
        let(:comment) { build(:comment, :by_guest, name: "admin") }

        it_behaves_like "the name is banned"
      end

      context "when the name is a capitalized version of one of the banned user names" do
        let(:comment) { build(:comment, :by_guest, name: "ADMIN") }

        it_behaves_like "the name is banned"
      end
    end
  end
end
