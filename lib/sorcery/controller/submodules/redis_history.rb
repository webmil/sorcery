module Sorcery
  module Controller
    module Submodules
      module RedisHistory
        def self.included(base)
          base.send(:include, InstanceMethods)
          Config.module_eval do
            class << self
              attr_accessor :register_history_login
              attr_accessor :register_history_logout
              attr_accessor :register_history_login_failed

              def merge_redis_history_defaults!
                @defaults.merge!(:@register_history_login        => true,
                                 :@register_history_logout       => true,
                                 :@register_history_login_failed => true,
                               )
              end
            end
            merge_redis_history_defaults!
          end
          Config.after_login          << :register_history_login
          Config.after_logout         << :register_history_logout
          Config.after_failed_login   << :register_history_login_failed
        end

        module InstanceMethods

          protected
          #
          def register_history_login(_user, _credentials)
            return unless Config.register_history_login
            _user.history_push(history_state('user:login'))
          end
          #
          def register_history_logout(_user)
            return unless Config.register_history_logout
            _user.history_push(history_state('user:logout'))
          end
          #
          def register_history_login_failed(credentials)
            return unless Config.register_history_login_failed
            _user = user_class.sorcery_adapter.find_by_credentials(credentials)
            _user.history_push(history_state('user:login_failed')) if _user
          end

          #
          private
          def history_state(action_name)
            user_agent = UserAgent.parse(request.user_agent)
            history_state = {
              action: action_name,
              time: Time.now.in_time_zone,
              ip_address: request.remote_ip,
              browser: user_agent.browser,
              platform: user_agent.platform,
              os: user_agent.os,
            }
          end
        end
      end
    end
  end
end