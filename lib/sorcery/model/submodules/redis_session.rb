module Sorcery
  module Model
    module Submodules
      #
      module RedisSession
        def self.included(base)
          base.extend(ClassMethods)
          base.send(:include, InstanceMethods)

          base.sorcery_config.class_eval do
            attr_accessor :session_ids_attribute_name
            attr_accessor :revoke_sessions_except_current_name
          end

          base.sorcery_config.instance_eval do
            @defaults.merge!(:@session_ids_attribute_name                  => :session_ids,
                             :@revoke_sessions_except_current_name         => :revoke_sessions_except_current,
                            )
            reset!
          end

          base.sorcery_config.after_config << :define_redis_session_fields
        end

        module InstanceMethods

          def cleanup_sessions
            return if send(sorcery_config.session_ids_attribute_name).blank?
            session_ids_to_clean_up = send(sorcery_config.session_ids_attribute_name).map do |session_id|
              session_id unless Redis.current.exists(session_key(session_id))
            end
            new_session_ids = send(sorcery_config.session_ids_attribute_name) - session_ids_to_clean_up
            sorcery_adapter.update_attribute(sorcery_config.session_ids_attribute_name, new_session_ids)
          end

          def set_session_id(session_id)
            new_session_ids = send(sorcery_config.session_ids_attribute_name) || []
            new_session_ids.push(session_id) if new_session_ids && new_session_ids.exclude?(session_id)
            sorcery_adapter.update_attribute(sorcery_config.session_ids_attribute_name, new_session_ids)
          end

          def sessions(current_session)
            return if send(sorcery_config.session_ids_attribute_name).blank?
            cleanup_sessions
            send(sorcery_config.session_ids_attribute_name)
              .map { |session_id| get_session(session_id, current_session) }
              .compact
              .sort_by { |h| h["last_action_time"]&.to_i }
              .reverse
          end

          def revoke_session(session_id)
            session_key = session_key(session_id)
            return unless Redis.current.exists(session_key)
            Redis.current.del(session_key)
            cleanup_sessions
          end

          private

          def get_session(session_id, current_session)
            session_key = session_key(session_id)

            return unless Redis.current.exists(session_key)
            redis_session = Marshal.load(Redis.current.get(session_key))
            return if redis_session.nil? || redis_session == {}
            return unless redis_session['user_id'] == self.id.to_s
            is_current_session = session_id == current_session.id
            last_action_time = Rails.application.config.sorcery.session_timeout_from_last_action ? current_session[:last_action_time] : current_session[:login_time]

            redis_session['timeout'] = is_current_session ?
              Rails.application.config.sorcery.session_timeout :
              (Rails.application.config.sorcery.session_timeout - (Time.now.in_time_zone - current_session[:last_action_time].to_time))

            redis_session['ttl'] = Redis.current.ttl(session_key)

            redis_session['current_session'] = is_current_session
            redis_session['id'] = session_id
            redis_session
          end

          def session_key(session_id)
            "session:#{session_id}"
          end

        end

        module ClassMethods
          protected

          def define_redis_session_fields
            sorcery_adapter.define_field sorcery_config.session_ids_attribute_name, Array
            sorcery_adapter.define_field sorcery_config.revoke_sessions_except_current_name, Boolean, default: false
          end
        end
      end
    end
  end
end
