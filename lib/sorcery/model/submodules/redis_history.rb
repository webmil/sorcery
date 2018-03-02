module Sorcery
  module Model
    module Submodules

      module RedisHistory

        SECONDS_IN_A_YEAR = 3600*24*365
        HISTORY_MAX_SIZE = 20

        module InstanceMethods

          def history_push(history_state)
            Redis.current.lpush(security_history_key, Marshal.dump(history_state))
            Redis.current.ltrim(security_history_key, 0, HISTORY_MAX_SIZE-1)
            Redis.current.expire(security_history_key, SECONDS_IN_A_YEAR)
          end

          def history_get(history_state)
            security_history = Redis.current.lrange(security_history_key, 0, @count-1)
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
