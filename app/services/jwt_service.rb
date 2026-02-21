# frozen_string_literal: true

module JwtService
  ALGORITHM = "HS256"
  EXPIRY = 24.hours

  def self.encode(payload, expiry = EXPIRY.from_now)
    payload = payload.merge(exp: expiry.to_i)
    JWT.encode(payload, secret, ALGORITHM)
  end

  def self.decode(token)
    decoded = JWT.decode(token, secret, true, algorithm: ALGORITHM)
    HashWithIndifferentAccess.new(decoded.first)
  rescue JWT::ExpiredSignature
    raise JWT::DecodeError, "Token has expired"
  end

  def self.secret
    ENV.fetch("JWT_SECRET") { Rails.application.secret_key_base }
  end
end
