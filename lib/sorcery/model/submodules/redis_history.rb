module Sorcery
  module Model
    module Submodules

      module RedisHistory

        def self.included(base)
          base.extend(ClassMethods)
          base.send(:include, InstanceMethods)

          base.sorcery_config.class_eval do
            attr_accessor :history_size_name
            attr_accessor :history_ttl_name
          end

          base.sorcery_config.instance_eval do
            @defaults.merge!(:@history_size_name => :history_size,
                             :@history_ttl_name => :history_ttl,)
            reset!
          end

          base.sorcery_config.after_config << :define_redis_history_fields
        end

        module ClassMethods

          protected

          def define_redis_history_fields
            sorcery_adapter.define_field sorcery_config.history_size_name, Integer, default: 20
            sorcery_adapter.define_field sorcery_config.history_ttl_name, Integer, default: 3600 * 24 * 365 #year
          end

        end

        module InstanceMethods

          def history_push(history_state)
            Redis.current.lpush(security_history_key, Marshal.dump(history_state))
            Redis.current.ltrim(security_history_key, 0, self.history_size - 1)
            Redis.current.expire(security_history_key, self.history_ttl)
          end

          def history(history_len)
            security_history = Redis.current.lrange(security_history_key, 0, history_len-1)
            security_history.map { |h| Marshal.load(h) }
          end

          def history_len
            Redis.current.llen(security_history_key)
          end

          private

          def security_history_key(session_id)
            "security_history:#{self.id.to_s}"
          end

        end

      end
    end
  end
end
