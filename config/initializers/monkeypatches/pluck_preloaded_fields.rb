# Interestingly, the performance of map vs. pluck is very unintuitive when
# applied to collections that have been pre-loaded using includes(). You can
# see this by running the following benchmark, which tries to retrieve tag
# names for 1000 different works:
#
#   Benchmark.bm do |b|
#     b.report("pluck with unloaded") do
#       t = Work.limit(1000).to_a
#       t.each do |item|
#         item.tags.pluck(:name)
#       end
#     end
#
#     b.report("map with unloaded") do
#       t = Work.limit(1000).to_a
#       t.each do |item|
#         item.tags.map(&:name)
#       end
#     end
#
#     b.report("pluck with preloaded") do
#       t = Work.includes(:tags).limit(1000).to_a
#       t.each do |item|
#         item.tags.pluck(:name)
#       end
#     end
#
#     b.report("map with preloaded") do
#       t = Work.includes(:tags).limit(1000).to_a
#       t.each do |item|
#         item.tags.map(&:name)
#       end
#     end
#   end
#
# The results of this benchmark on my machine were:
#
#                             user     system      total        real
# pluck with unloaded     3.800000   0.180000   3.980000 (  4.465598)
# map with unloaded       4.590000   0.180000   4.770000 (  5.305971)
# pluck with preloaded    2.680000   0.080000   2.760000 (  2.803320)
# map with preloaded      1.920000   0.030000   1.950000 (  1.987080)
#
# Preloading data with includes() helps both pluck() and map() run faster, but
# while pluck() is faster than map() with unloaded data, map() is almost a
# second faster than pluck() with preloaded data, making it the fastest of the
# four techniques. (Note that in Rails 5, pluck() was revised to take advantage
# of preloaded data like this, so the time difference isn't a result of pluck
# performing additional database queries. The performance hit is ruby-only.)
#
# The difference between map() and pluck() in this case is even more striking
# if you eliminate the time that it takes to perform the preloading:
#
#   Benchmark.bm do |b|
#     loaded = Work.includes(:tags).limit(1000).to_a
#
#     b.report("pluck after preloading") do
#       loaded.each do |item|
#         item.tags.pluck(:name)
#       end
#     end
#
#     b.report("map after preloading") do
#       loaded.each do |item|
#         item.tags.map(&:name)
#       end
#     end
#   end
#
# The results of this experiment on my machine were:
#
#                             user     system      total        real
# pluck after preloading  1.040000   0.010000   1.050000 (  1.055646)
# map after preloading    0.020000   0.000000   0.020000 (  0.020231)
#
# Effectively, map() runs about 50x faster than pluck() in this case. This is
# the purpose of this monkey-patch: to ensure that the performance of pluck()
# when a collection has already been loaded is more in line with the
# performance of map(). There is of course a little overhead, but with this
# monkeypatch enabled, the benchmark results become:
#
#                             user     system      total        real
# pluck after preloading  0.070000   0.000000   0.070000 (  0.066784)
# map after preloading    0.020000   0.000000   0.020000 (  0.021235)
#
# If at any point you disable this patch, run the benchmarks, and discover that
# pluck's performance has improved to match the performance of map, this whole
# file should be discarded.
module ActiveRecord
  module Associations
    class CollectionProxy
      alias :default_pluck :pluck

      def pluck(*column_names)
        if loaded?
          begin
            if column_names.size == 0
              map { nil }
            elsif column_names.size == 1
              field = column_names.first.to_sym
              map { |item| item.send(field) }
            else
              fields = column_names.map(&:to_sym)
              map { |item| fields.map { |field| item.send(field) } }
            end
          rescue
            default_pluck(*column_names)
          end
        else
          default_pluck(*column_names)
        end
      end
    end
  end
end
