module ActivePresenter
  # Base class for presenters. See README for usage.
  #
  class Base
    include ActiveSupport::Callbacks
    define_callbacks :before_validation, :before_save, :after_save
    
    class_inheritable_accessor :presented
    self.presented = {}
    
    # Indicates which models are to be presented by this presenter.
    # i.e.
    #
    #   class SignupPresenter < ActivePresenter::Base
    #     presents :user, :account
    #   end
    #
    #
    def self.presents(*types)
      attr_accessor *types
      
      types.each do |t|
        define_method("#{t}_errors") do
          send(t).errors
        end
        
        presented[t] = t.to_s.tableize.classify.constantize
      end
    end
    
    def self.human_attribute_name(attribute_name)
      presentable_type = presented.keys.detect do |type|
        attribute_name.to_s.starts_with?("#{type}_")
      end
      
      attribute_name.to_s.gsub("#{presentable_type}_", "").humanize
    end
    
    # Accepts arguments in two forms. For example, if you had a SignupPresenter that presented User, and Account, you could specify arguments in the following two forms:
    #
    #   1. SignupPresenter.new(:user_login => 'james', :user_password => 'swordfish', :user_password_confirmation => 'swordfish', :account_subdomain => 'giraffesoft')
    #     - This form is useful for initializing a new presenter from the params hash: i.e. SignupPresenter.new(params[:signup_presenter])
    #   2. SignupPresenter.new(:user => User.find(1), :account => Account.find(2))
    #     - This form is useful if you have instances that you'd like to edit using the presenter. You can subsequently call presenter.update_attributes(params[:signup_presenter]) just like with a regular AR instance.
    #
    # Both forms can also be mixed together: SignupPresenter.new(:user => User.find(1), :user_login => 'james')
    #   In this case, the login attribute will be updated on the user instance provided.
    # 
    # If you don't specify an instance, one will be created by calling Model.new
    #
    def initialize(args = {})
      args ||= {}
      
      presented.each do |type, klass|
        send("#{type}=", args[type].is_a?(klass) ? args.delete(type) : klass.new)
      end
      
      self.attributes = args
    end
<<<<<<< HEAD:lib/active_presenter/base.rb
    
    def id
      return nil if presented_instances.map(&:new_record?).all?
      presented_instances.detect {|i| !i.new_record?}.id
    end
    
=======

>>>>>>> james:lib/active_presenter/base.rb
    # Set the attributes of the presentable instances using the type_attribute form (i.e. user_login => 'james')
    #
    def attributes=(attrs)
      attrs.each { |k,v| send("#{k}=", v) unless attribute_protected?(k)}
    end
    
    # Makes sure that the presenter is accurate about responding to presentable's attributes, even though they are handled by method_missing.
    #
    def respond_to?(method)
      presented_attribute?(method) || super
    end
    
    # Handles the decision about whether to delegate getters and setters to presentable instances.
    #
    def method_missing(method_name, *args, &block)
      presented_attribute?(method_name) ? delegate_message(method_name, *args, &block) : super
    end
    
    # Returns an instance of ActiveRecord::Errors with all the errors from the presentables merged in using the type_attribute form (i.e. user_login).
    #
    def errors
      @errors ||= ActiveRecord::Errors.new(self)
    end
    
    # Returns boolean based on the validity of the presentables by calling valid? on each of them.
    #
    def valid?
      errors.clear
      if run_callbacks_with_halt(:before_validation)
        presented.keys.each do |type|
          presented_inst = send(type)

          next unless save?(type, presented_inst)
          merge_errors(presented_inst, type) unless presented_inst.valid?
        end

        errors.empty?
      end
    end
    
    # Save all of the presentables, wrapped in a transaction.
    # 
    # Returns true or false based on success.
    #
    def save
      saved = false
      
      ActiveRecord::Base.transaction do
        if valid? && run_callbacks_with_halt(:before_save)
          saved = presented.keys.select {|key| save?(key, send(key))}.all? {|key| send(key).save}
          raise ActiveRecord::Rollback unless saved # TODO: Does this happen implicitly?
        end

        run_callbacks_with_halt(:after_save) if saved
      end
      
      saved
    end
    
    # Save all of the presentables wrapped in a transaction.
    #
    # Returns true on success, will raise otherwise.
    # 
    def save!
      raise ActiveRecord::RecordInvalid.new(self) unless valid?
      raise ActiveRecord::RecordNotSaved unless run_callbacks_with_halt(:before_save)
      
      ActiveRecord::Base.transaction do
        presented.keys.select {|key| save?(key, send(key))}.each {|key| send(key).save!}

        run_callbacks_with_halt(:after_save)
      end

      true
    end
    
    # Update attributes, and save the presentables
    #
    # Returns true or false based on success.
    #
    def update_attributes(attrs)
      self.attributes = attrs
      save
    end
    
<<<<<<< HEAD:lib/active_presenter/base.rb
    # Should this presented instance be saved?  By default, this returns true
    # Called from #save and #save!
    #
    # For
    #  class SignupPresenter < ActivePresenter::Base
    #    presents :account, :user
    #  end
    #
    # #save? will be called twice:
    #  save?(:account, #<Account:0x1234dead>)
    #  save?(:user, #<User:0xdeadbeef>)
    def save?(presented_key, presented_instance)
      true
    end

=======
    # We define #id and #new_record? to play nice with form_for(@presenter) in Rails
    def id # :nodoc:
      nil
    end

    def new_record?
      true
    end
    
>>>>>>> james:lib/active_presenter/base.rb
    protected
      def presented_instances
        presented.keys.map { |key| send(key) }
      end
      
      def delegate_message(method_name, *args, &block)
        presentable = presentable_for(method_name)
        send(presentable).send(flatten_attribute_name(method_name, presentable), *args, &block)
      end
      
      def presentable_for(method_name)
        presented.keys.sort_by { |k| k.to_s.size }.reverse.detect do |type|
          method_name.to_s.starts_with?(attribute_prefix(type))
        end
      end
    
      def presented_attribute?(method_name)
        p = presentable_for(method_name)
        !p.nil? && send(p).respond_to?(flatten_attribute_name(method_name,p))
      end
      
      def flatten_attribute_name(name, type)
        name.to_s.gsub(/^#{attribute_prefix(type)}/, '')
      end
      
      def attribute_prefix(type)
        "#{type}_"
      end
      
      def merge_errors(presented_inst, type)
        presented_inst.errors.each do |att,msg|
          errors.add(attribute_prefix(type)+att, msg)
        end
      end
      
      def attribute_protected?(name)
        presentable    = presentable_for(name)
        return false unless presentable
        flat_attribute = {flatten_attribute_name(name, presentable) => ''} #remove_att... normally takes a hash, so we use a ''
        presentable.to_s.tableize.classify.constantize.new.send(:remove_attributes_protected_from_mass_assignment, flat_attribute).empty?
      end
      
      def run_callbacks_with_halt(callback)
        run_callbacks(callback) { |result, object| result == false }
      end
  end
end
