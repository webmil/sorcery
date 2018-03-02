module Sorcery
  module Model
    module Submodules

      module TrustedNetwork
        def self.included(base)
          base.extend(ClassMethods)
          base.send(:include, InstanceMethods)

          base.sorcery_config.class_eval do
            attr_accessor :trusted_network_attribute_name
          end

          base.sorcery_config.instance_eval do
            @defaults.merge!(:@trusted_network_attribute_name => :trusted_network)
            reset!
          end

          base.validate :validate_trusted_network
          base.sorcery_config.before_authenticate << :prevent_untrusted_network_login
          base.sorcery_config.after_config << :define_trusted_network_fields
        end

        module InstanceMethods

          private

          def prevent_untrusted_network_login
            # return false, :untrusted_network unless login_from_trusted_network?
            true
          end

          def login_from_trusted_network?
            begin
              return true if send(sorcery_config.trusted_network_attribute_name).empty?
              current_ipa = IPAddress.parse(request.remote_ip)
              send(sorcery_config.trusted_network_attribute_name).each do |trusted_ipn|
                trusted_subnet = IPAddress.parse(trusted_ipn)
                return true if trusted_subnet.include? current_ipa
              end
              return false
            rescue => error
              return false
            end
          end

          def validate_trusted_network
            send(sorcery_config.trusted_network_attribute_name).each do |address|
              begin
                IPAddress.parse(address)
              rescue => error
                errors.add(:trusted_network, :invalid, message: "invalid IP Network: #{address}. #{error}")
              end
            end
          end

        end

        module ClassMethods
          protected

          def define_trusted_network_fields
            sorcery_adapter.define_field sorcery_config.trusted_network_attribute_name, Array, default: []
          end

        end

      end
    end
  end
end
