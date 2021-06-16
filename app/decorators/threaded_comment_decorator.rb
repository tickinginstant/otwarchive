# A class designed to help calculate whether a hidden comment has replies that
# should be displayed. Also helps reduce N+1 errors on comment pages by loading
# all the comments in a thread at a time.
class ThreadedCommentDecorator < SimpleDelegator
  # Given a single root comment, wraps the root and all of its descendants in a
  # ThreadedCommentDecorator.
  #
  # The optional parameter "loaded" is intended to help with N+1 errors. If the
  # root was loaded with the scope for_threaded_display, we don't need to load
  # any additional information (and in fact, trying to load more information
  # would result in an N+1 error).
  def self.decorate(root, loaded: false)
    # Load all comments in the thread.
    descendants = if root.id == root.thread
                    root.thread_comments
                  else
                    # TODO: Once AO3-5939 is fixed, it'd be nice to use
                    # full_set here.
                    Comment.find(root.thread).thread_comments
                  end

    # If we haven't already loaded the associated records (comment.parent,
    # comment.pseud, comment.pseud.user), load them now:
    descendants = descendants.for_display unless loaded

    # Decorate each descendant:
    all = descendants.map { |comment| new(comment) }

    # Compute the list of replies for each comment, and assign them so that we
    # have easy access in the future:
    replies = all.select(&:reply_comment?).group_by(&:commentable_id)
    all.each do |comment|
      # Sorting by id ensures that we will see the replies in the order that
      # they were originally added.
      #
      # TODO: Maybe we should sort by threaded_left once AO3-5939 is fixed?
      comment.replies = (replies[comment.id] || []).sort_by(&:id)
    end

    # Return the decorated version of the root comment:
    all.find { |comment| comment.id == root.id }
  end

  # A list keeping track of all replies to this comment.
  #
  # This is roughly equivalent to calling comment.comments, but using
  # comment.replies is much more efficient, and ensures that all of the replies
  # are already wrapped in a ThreadedCommentDecorator.
  attr_accessor :replies

  # Returns a list of all replies that are either visible, or have visible
  # descendants (and therefore should be displayed as placeholders).
  #
  # Stores the result in a variable to reduce computation.
  def visible_replies
    @visible_replies ||= replies.select do |reply|
      reply.visible? || reply.visible_descendants?
    end
  end

  # Count the number of visible descendants that this comment has.
  #
  # Stores the result in a variable to reduce computation.
  def count_visible_descendants
    @count_visible_descendants ||= replies.sum do |reply|
      (reply.visible? ? 1 : 0) + reply.count_visible_descendants
    end
  end

  # Check whether this comment has any descendants that are visible.
  def visible_descendants?
    count_visible_descendants.positive?
  end

  # Returns true if this comment should be visible, false otherwise.
  # Delegates the actual calculation to the comment class.
  #
  # Stores the result in a variable to reduce computation.
  def visible?
    return @visible unless @visible.nil?

    @visible = __getobj__.visible?
  end
end
