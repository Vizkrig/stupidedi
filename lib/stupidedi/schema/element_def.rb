# frozen_string_literal: true

module Stupidedi
  include Refinements

  module Schema

    class AbstractElementDef < AbstractDef
      include Inspect

      # @return [String]
      attr_reader :id

      # @return [String]
      attr_reader :name

      # @return [String]
      attr_reader :description

      abstract :simple?

      abstract :composite?

      # @return [AbstractSet<CodeList>]
      abstract :code_lists

      def element?
        true
      end
    end

    #
    # @see X222 B.1.1.3.1 Data Element
    #
    class SimpleElementDef < AbstractElementDef

      # @return [SimpleElementUse, ComponentElementUse]
      abstract :parent

      # @return [SimpleElementVal]
      abstract :empty, :args => %w(position)

      # @return [SimpleElementVal]
      abstract :value, :args => %w(object position)

      # @return [SimpleElementVal]
      abstract :parse, :args => %w(string position)

      # @return true
      def simple?
        true
      end

      # @return false
      def composite?
        false
      end

      # @return [SimpleElementUse]
      def simple_use(requirement, repeat_count, parent = nil)
        SimpleElementUse.new(self, requirement, repeat_count, Sets.universal, parent)
      end

      # @return [ComponentElementUse]
      def component_use(requirement, parent = nil)
        ComponentElementUse.new(self, requirement, Sets.universal, parent)
      end

      # This is overridden (if needed) by the concrete subclasses. Specifically
      # the "ID" element types have an extra attribute to link the CodeList.
      #
      # @return [AbstractSet<CodeList>]
      def code_lists(subset = Sets.universal)
        Sets.empty
      end
    end

    #
    # @see X222 B.1.1.3.3 Composite Data Structure
    #
    class CompositeElementDef < AbstractElementDef

      # @return [Array<ComponentElementUse>]
      attr_reader :component_uses

      # @return [Array<SyntaxNote>]
      attr_reader :syntax_notes

      # @return [CompositeElementUse]
      attr_reader :parent

      def initialize(id, name, description, component_uses, syntax_notes, parent)
        @id, @name, @description, @component_uses, @syntax_notes, @parent =
          id, name, description, component_uses, syntax_notes, parent

        # Delay re-parenting until the entire definition tree has a root
        # to prevent unnecessarily copying objects
        unless parent.nil?
          @component_uses = @component_uses.map{|x| x.copy(:parent => self) }
        end
      end

      # @return [CompositeElementDef]
      def copy(changes = {})
        CompositeElementDef.new \
          changes.fetch(:id, @id),
          changes.fetch(:name, @name),
          changes.fetch(:description, @description),
          changes.fetch(:component_uses, @component_uses),
          changes.fetch(:syntax_notes, @syntax_notes),
          changes.fetch(:parent, @parent)
      end

      # @return false
      def simple?
        false
      end

      # @return true
      def composite?
        true
      end

      # @return [CompositeElementUse]
      def simple_use(requirement, repeat_count, parent = nil)
        CompositeElementUse.new(self, requirement, repeat_count, parent)
      end

      # @return [CompositeElementVal]
      def value(component_vals, usage, position)
        Values::CompositeElementVal.new(component_vals, usage)
      end

      # @return [CompositeElementVal]
      def empty(usage, position)
        Values::CompositeElementVal.new([], usage)
      end

      # @return [AbstractSet<CodeList>]
      def code_lists
        @component_uses.map(&:code_lists).inject(&:|)
      end

      # @return [void]
      def pretty_print(q)
        q.text("CompositeElementDef[#{@id}]")
        q.group(2, "(", ")") do
          q.breakable ""
          @component_uses.each do |e|
            unless q.current_group.first?
              q.text ","
              q.breakable
            end
            q.pp e
          end
        end
      end
    end

    class << CompositeElementDef
      # @group Constructors
      #########################################################################

      # @return [CompositeElementDef]
      def build(id, name, description, *args)
        component_uses = args.take_while{|x| x.is_a?(AbstractElementUse) }
        syntax_notes   = args.drop(component_uses.length)

        new(id, name, description, component_uses, syntax_notes, nil)
      end

      # @endgroup
      #########################################################################
    end

  end
end
