#require 'facets/hash/insert'
module Og

require 'relation/refers_to'

class BelongsTo < RefersTo

  def enchant
    super
    target_class.ann!(:self)[:descendants] ||= []
    target_class.ann!(:self, :descendants) << [owner_class, foreign_key]
  end

end

end
