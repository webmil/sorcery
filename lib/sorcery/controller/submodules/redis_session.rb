module Sorcery
  module Controller
    module Submodules
      module RedisSession
        def self.included(base)
          base.send(:include, InstanceMethods)
          Config.module_eval do
            class << self
              attr_accessor :register_useragent_to_session

              def merge_redis_session_defaults!
                @defaults.merge!(:@register_useragent_to_session => true)
              end
            end
            merge_redis_session_defaults!
          end
          Config.after_login          << :register_ip_address_to_session
          Config.after_login          << :register_session_id_to_user
          Config.after_login          << :register_useragent_to_session
          Config.after_login          << :revoke_sessions_except_current
        end

        module InstanceMethods

          protected

          # Add session_id to user.session_ids array
          def register_session_id_to_user(_user, _credentials)
            _user.cleanup_sessions
            _user.set_session_id(session.id)
          end

          # Updates uearagent data on every login.
          # This runs as a hook just after a successful login.
          def register_useragent_to_session(_user, _credentials)
            return unless Config.register_useragent_to_session
            user_agent = UserAgent.parse(request.user_agent)
            session[:browser] = user_agent.browser
            session[:platform] = user_agent.platform
            session[:os] = user_agent.os
          end

          # Updates IP address on every login.
          # This runs as a hook just after a successful login.
          def register_ip_address_to_session(_user, _credentials)
            return unless Config.register_last_ip_address
            session[:ip_address] = request.remote_ip
          end

          #
          def revoke_sessions_except_current(_user, _credentials)
            return unless _user.revoke_sessions_except_current
            _user.sessions(session).each do |redis_session|
              _user.revoke_session(redis_session['id']) unless redis_session['current_session']
            end
          end
        end
      end
    end
  end
end
