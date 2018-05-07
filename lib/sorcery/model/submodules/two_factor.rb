module Sorcery
  module Model
    module Submodules
      module TwoFactor
        def self.included(base)
          base.extend(ClassMethods)
          base.send(:include, InstanceMethods)

          base.sorcery_config.class_eval do
            attr_accessor :otp_secret_name,
                          :otp_issuer,
                          :otp_drift

          end

          base.sorcery_config.instance_eval do
            @defaults.merge!( :@otp_secret_name     => :otp_secret,
                              :@otp_issuer          => 'issuer_name',
                              :@otp_drift           => 30
                            )
            reset!
          end

          base.sorcery_config.after_config << :define_two_factor_fields
        end

        module InstanceMethods
          require 'rqrcode'
          require 'rotp'

          def totp_create
            secret = generate_secret
            qrcode = RQRCode::QRCode.new( provisioning_uri(secret), level: :h, mode: :QRAlphanumeric ).as_png(
              resize_gte_to: false,
              resize_exactly_to: false,
              fill: 'white',
              color: 'black',
              size: 200,
              border_modules: 4,
              module_px_size: 6,
              file: nil # path to write
            ).to_data_url

            {
              qrcode: qrcode,
              secret: secret,
            }

          end

          def totp_valid?(passcode, secret = nil)
            totp(user_otp_secret || secret).verify_with_drift(passcode, sorcery_config.otp_drift)
          end

          def otp_required?
            user_otp_secret.present?
          end

          def save_secret!(secret)
            update_otp_secret(secret)
          end

          def clear_secret!
            update_otp_secret(nil)
          end

          def generate_secret
            secret = ROTP::Base32.random_base32
          end

          def current_totp
            totp(user_otp_secret).now
          end

          alias tfa_enabled? otp_required?

          private

          def update_otp_secret(new_secret)
            sorcery_adapter.update_attribute(sorcery_config.otp_secret_name, new_secret)
          end

          def user_otp_secret
            send(sorcery_config.otp_secret_name)
          end

          def provisioning_uri(secret)
            totp(secret).provisioning_uri(self.email)
          end

          def totp(secret)
            ROTP::TOTP.new(secret, issuer: sorcery_config.otp_issuer)
          end

        end

        module ClassMethods

          protected

          def define_two_factor_fields
            sorcery_adapter.define_field sorcery_config.otp_secret_name, String, default: nil
          end

        end

      end
    end
  end
end
