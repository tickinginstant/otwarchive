module CommentParent
  extend ActiveSupport::Concern

  include CommentUltimateParent

  included do
    has_many :comments, as: :commentable, dependent: :delete_all
    has_many :total_comments, class_name: "Comment", as: :parent, dependent: :delete_all
  end
end
