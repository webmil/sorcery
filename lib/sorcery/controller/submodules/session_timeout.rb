module Sorcery
  module Controller
    module Submodules
      # This submodule helps you set a timeout to all user sessions.
      # The timeout can be configured and also you can choose to reset it on every user action.
      module SessionTimeout
        def self.included(base)
          base.send(:include, InstanceMethods)
          Config.module_eval do
            class << self
              # how long in seconds to keep the session alive.
              attr_accessor :session_timeout
              # use the last action as the beginning of session timeout.
              attr_accessor :session_timeout_from_last_action

              def merge_session_timeout_defaults!
                @defaults.merge!(:@session_timeout                      => 3600, # 1.hour
                                 :@session_timeout_from_last_action     => false)
              end
            end
            merge_session_timeout_defaults!
          end
          Config.after_login << :register_login_time
          base.prepend_before_action :validate_session_timeout
        end

        module InstanceMethods
          protected

          attr_accessor :session_timeouted

          # Registers last login to be used as the timeout starting point.
          # Runs as a hook after a successful login.
          def register_login_time(_user, _credentials)
            session[:login_time] = session[:last_action_time] = Time.now.in_time_zone
          end

          # Checks if session timeout was reached and expires the current session if so.
          # To be used as a before_action, before require_login
          def validate_session_timeout
            if sorcery_session_timeout?
              reset_sorcery_session
              session_timeouted = true
              remove_instance_variable :@current_user if defined? @current_user
            else
              session[:last_action_time] = Time.now.in_time_zone
            end
          end

          def sorcery_session_timeout?
            session_to_use = Config.session_timeout_from_last_action ? session[:last_action_time] : session[:login_time]
            session_to_use && (Time.now.in_time_zone - session_to_use.to_time > Config.session_timeout)
          end
        end
      end
    end
  end
end
