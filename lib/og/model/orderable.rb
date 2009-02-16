require 'facets/paramix'

module Og::Mixin

def Orderable(options)
  options = options.rekey(&:to_sym)
  #ParametricMixin.new(Orderable) do
  Paramix.new(Orderable) do
    alias_method options[:position], :position if options[:position]
    #attr_accessor options[:type] if options[:type]
  end
end


# Attach list/ordering methods to the enchanted class.
#
# === Comments
#
# If you use the scope option, you have to set he parent (scope)
# of the object before inserting to have correct ordering.

module Orderable

  def orderable_options
    self.class.parametric_options[Orderable] || {}
  end

  attr :position

  #def self.parametric_options
  #  @parametic_options ||= {}
  #end

  #def self.parametric_options=(opts)
  #  @parametic_options = opts
  #end

  # Return and reset parmetric options
  #def self.parametric_options!
  #  ref = parametric_options
  #  @parametric_options = nil
  #  return ref
  #end

  #def self.included(base)
  #  base.module_eval %{
  #    attr_accessor :#{opt_position}, #{opt_type}
  #  }
  #end 

  def orderable_position
    orderable_options[:position] || "position"
  end

  def orderable_type
    orderable_options[:type] || Fixnum
  end

  # scope field (cleaned)

  def orderable_scope
    scope = orderable_options[:scope]
    if scope
      if scope.to_s !~ /_oid$/
        scope = "#{scope}_oid".to_sym
      else
        scope = scope.to_sym
      end
    end
    scope
  end

  def orderable_condition
    scope = orderable_scope
    if scope
      scope_value = send(scope)
      scope = scope_value ? "\#{scope} = \#{scope_value}" : "\#{scope} IS NULL"
    end
    cond = orderable_options[:condition]
    return [ cond, scope ].compact
  end

  def current_position
    instance_variable_get("@#{orderable_position}")
  end

  def current_position=(pos)
    instance_variable_set("@#{orderable_position}", pos)
  end


  before :og_insert do 
    add_to_bottom()
  end
  
  before :og_delete do
    decrement_position_of_lower_items()
  end

  # Move higher.
  
  def move_higher
    if higher = higher_item
      self.class.transaction do
        higher.increment_position
        decrement_position
      end
    end
  end
  
  # Move lower.
  
  def move_lower
    if lower = lower_item
      self.class.transaction do
        lower.decrement_position
        increment_position
      end
    end
  end

  # Move to the top.
  
  def move_to_top
    self.class.transaction do
      increment_position_of_higher_items
      set_top_position
    end
  end

  # Move to the bottom.
  
  def move_to_bottom
    self.class.transaction do
      decrement_position_of_lower_items
      set_bottom_position
    end
  end

  # Move to a specific position.
  
  def move_to(dest_position)
    return if self.current_position == dest_position

    pos = orderable_position
    con = orderable_condition

    self.class.transaction do
      if current_position < dest_position
        adj = "#{pos} = #{pos} - 1"
        con = con + [ "#{pos} > #{current_position}", "#{pos} <= #{dest_position}" ]
      else
        adj = "#{pos} = #{pos} + 1"
        con = con + [ "#{pos} < #{current_position}", "#{pos} >= #{dest_position}" ]
      end
      self.class.update( adj, :condition => con.join(' AND ') )
      self.current_position = dest_position
      update_attribute(orderable_position)
    end

    self
  end

  def add_to_top
    increment_position_of_all_items
  end

  def add_to_bottom
    self.current_position = bottom_position + 1
  end

  def add_to
    # TODO
  end

  def higher_item
    pos = orderable_position
    con = orderable_condition + [ "#{pos} = #{current_position - 1}" ]
    self.class.one( :condition => con.join(' AND ') )
  end
  alias_method :previous_item, :higher_item

  def lower_item
    pos = orderable_position
    con = orderable_condition + [ "#{pos} = #{current_position + 1}" ]
    self.class.one( :condition => con.join(' AND ') )
  end
  alias_method :next_item, :lower_item

  def top_item
    # TODO
  end
  alias_method :first_item, :top_item

  def bottom_item
    pos = orderable_position
    con = orderable_condition
    con = con.empty? ? nil : con.join(' AND ')
    self.class.one(:condition => con, :order => "#{pos} DESC", :limit => 1)
  end
  alias_method :last_item, :last_item

  def top?
    self.current_position == 1
  end
  alias_method :first?, :top?

  def bottom?
    self.current_position == bottom_position
  end
  alias_method :last?, :bottom?

  def increment_position
    self.current_position += 1
    update_attribute(self.orderable_position)
  end

  def decrement_position
    self.current_position -= 1
    update_attribute(self.orderable_position)
  end

  def bottom_position
    item = bottom_item
    item ? (item.current_position || 0) : 0
  end

  def set_top_position
    self.current_position = 1
    update_attribute(orderable_position)
  end

  def set_bottom_position
    self.current_position = bottom_position + 1
    update_attribute(orderable_position)
  end

  def increment_position_of_higher_items
    pos = orderable_position
    con = orderable_condition + [ "#{pos} < #{current_position}" ]
    self.class.update "#{pos}=(#{pos} + 1)",  :condition => con.join(' AND ')
  end

  def increment_position_of_all_items
    pos = orderable_position
    con = orderable_condition
    con = con.empty? ? nil : con.join(' AND ')
    self.class.update "#{pos}=(#{pos} + 1)", :condition => con 
  end

  def decrement_position_of_lower_items
    pos = orderable_position
    con = orderable_condition + [ "#{pos} > #{current_position}" ]
    self.class.update "#{pos}=(#{pos} - 1)",  :condition => con.join(' AND ')
  end

end

end

