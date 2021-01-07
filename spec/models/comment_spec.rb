# frozen_string_literal: true

require "spec_helper"

describe Comment do
  describe "#create" do
    context "with an existing comment from the same user" do
      let(:first_comment) { create(:comment) }

      let(:second_comment) do
        attributes = %w[pseud_id commentable_id commentable_type comment_content name email]
        Comment.new(first_comment.attributes.slice(*attributes))
      end

      it "is invalid if exactly duplicated" do
        expect(second_comment.valid?).to be_falsy
        expect(second_comment.errors.keys).to include(:comment_content)
      end

      it "is not invalid if in the process of being deleted" do
        second_comment.is_deleted = true
        expect(second_comment.valid?).to be_truthy
      end
    end

    context "for a complex set of comments" do
      let(:parent) { create(:admin_post) }

      let!(:root) { create(:comment, commentable: parent) }
      let!(:child1) { create(:comment, commentable: root) }
      let!(:child2) { create(:comment, commentable: root) }
      let!(:grandchild1a) { create(:comment, commentable: child1) }
      let!(:grandchild1b) { create(:comment, commentable: child1) }
      let!(:grandchild2a) { create(:comment, commentable: child2) }
      let!(:grandchild2b) { create(:comment, commentable: child2) }

      it "assigns threaded_left and threaded_right correctly" do
        expect(root.reload.threaded_left).to eq(1)
        expect(child1.reload.threaded_left).to eq(2)
        expect(grandchild1a.reload.threaded_left).to eq(3)
        expect(grandchild1a.threaded_right).to eq(4)
        expect(grandchild1b.reload.threaded_left).to eq(5)
        expect(grandchild1b.threaded_right).to eq(6)
        expect(child1.threaded_right).to eq(7)
        expect(child2.reload.threaded_left).to eq(8)
        expect(grandchild2a.reload.threaded_left).to eq(9)
        expect(grandchild2a.threaded_right).to eq(10)
        expect(grandchild2b.reload.threaded_left).to eq(11)
        expect(grandchild2b.threaded_right).to eq(12)
        expect(child2.threaded_right).to eq(13)
        expect(root.threaded_right).to eq(14)
      end
    end
  end

  describe "#destroy_or_mark_deleted" do
    context "for a complex set of comments" do
      let(:parent) { create(:admin_post) }

      let!(:root) { create(:comment, commentable: parent) }
      let!(:child1) { create(:comment, commentable: root) }
      let!(:child2) { create(:comment, commentable: root) }
      let!(:grandchild1a) { create(:comment, commentable: child1) }
      let!(:grandchild1b) { create(:comment, commentable: child1) }
      let!(:grandchild2a) { create(:comment, commentable: child2) }
      let!(:grandchild2b) { create(:comment, commentable: child2) }

      it "doesn't change threading when removing a comment with replies" do
        child1.destroy_or_mark_deleted

        expect { child1.reload }.not_to raise_exception

        expect(root.reload.threaded_left).to eq(1)
        expect(child1.reload.threaded_left).to eq(2)
        expect(grandchild1a.reload.threaded_left).to eq(3)
        expect(grandchild1a.threaded_right).to eq(4)
        expect(grandchild1b.reload.threaded_left).to eq(5)
        expect(grandchild1b.threaded_right).to eq(6)
        expect(child1.threaded_right).to eq(7)
        expect(child2.reload.threaded_left).to eq(8)
        expect(grandchild2a.reload.threaded_left).to eq(9)
        expect(grandchild2a.threaded_right).to eq(10)
        expect(grandchild2b.reload.threaded_left).to eq(11)
        expect(grandchild2b.threaded_right).to eq(12)
        expect(child2.threaded_right).to eq(13)
        expect(root.threaded_right).to eq(14)
      end

      it "does change threading when removing a comment with no replies" do
        grandchild1b.destroy_or_mark_deleted

        expect { grandchild1b.reload }.to raise_exception(ActiveRecord::RecordNotFound)

        expect(root.reload.threaded_left).to eq(1)
        expect(child1.reload.threaded_left).to eq(2)
        expect(grandchild1a.reload.threaded_left).to eq(3)
        expect(grandchild1a.threaded_right).to eq(4)
        expect(child1.threaded_right).to eq(5)
        expect(child2.reload.threaded_left).to eq(6)
        expect(grandchild2a.reload.threaded_left).to eq(7)
        expect(grandchild2a.threaded_right).to eq(8)
        expect(grandchild2b.reload.threaded_left).to eq(9)
        expect(grandchild2b.threaded_right).to eq(10)
        expect(child2.threaded_right).to eq(11)
        expect(root.threaded_right).to eq(12)
      end

      it "removes a placeholder after its replies have been deleted" do
        child1.destroy_or_mark_deleted
        grandchild1a.destroy_or_mark_deleted
        grandchild1b.destroy_or_mark_deleted

        expect { child1.reload }.to raise_exception(ActiveRecord::RecordNotFound)
        expect { grandchild1a.reload }.to raise_exception(ActiveRecord::RecordNotFound)
        expect { grandchild1b.reload }.to raise_exception(ActiveRecord::RecordNotFound)

        expect(root.reload.threaded_left).to eq(1)
        expect(child2.reload.threaded_left).to eq(2)
        expect(grandchild2a.reload.threaded_left).to eq(3)
        expect(grandchild2a.threaded_right).to eq(4)
        expect(grandchild2b.reload.threaded_left).to eq(5)
        expect(grandchild2b.threaded_right).to eq(6)
        expect(child2.threaded_right).to eq(7)
        expect(root.threaded_right).to eq(8)
      end
    end
  end
end
