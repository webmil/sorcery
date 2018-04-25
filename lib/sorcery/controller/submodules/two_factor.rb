module Sorcery
  module Controller
    module Submodules
      #
      #
      module TwoFactor
        def self.included(base)
          base.send(:include, InstanceMethods)
        end


        module InstanceMethods

          # Override.
          # logins a user instance
          def auto_login(user, should_remember = false)
            session[:user_id] = user.id.to_s
            session[:otp] = -1 if user.otp_required?
            @current_user = user
          end

          #
          def enable_2fa(_user, secret, passcode)
            return false if !secret.present? && !passcode.present?
            totp_valid = totp_valid?(_user, passcode, secret)
            result = totp_valid ? _user.save_secret!(secret) : false
            after_2fa_anabled!(_user) if result
            result
          end

          #
          def disable_2fa(_user, passcode)
            return false if !passcode.present?
            totp_valid = totp_valid?(_user, passcode)
            result = totp_valid ? _user.clear_secret! : false
            after_2fa_disabled!(_user) if result
            result
          end

          #
          def totp_valid?(_user, passcode, secret = nil)
            return unless _user
            result = _user.totp_valid?(passcode, secret)
            after_2fa_pass_failed!(_user) unless result
            result
          end

          private

          def after_2fa_anabled!(_user)
            Config.after_2fa_anabled.each { |c| send(c, _user) }
          end

          def after_2fa_disabled!(_user)
            Config.after_2fa_disabled.each { |c| send(c, _user) }
          end

          def after_2fa_pass_failed!(_user)
            Config.after_2fa_pass_failed.each { |c| send(c, _user) }
          end

        end
      end
    end
  end
end
