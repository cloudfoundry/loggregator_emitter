require 'digest/sha1'
require 'openssl'

module Encryption
  class Symmetric
    AES_BLOCKSIZE = 16

    def encrypt(key, message)
      cipher = OpenSSL::Cipher::AES128.new(:CBC)
      cipher.encrypt
      cipher.key = get_encryption_key(key)
      iv = cipher.random_iv

      iv + cipher.update(message) + cipher.final
    end

    def decrypt(key, encrypted)
      cipher = OpenSSL::Cipher::AES128.new(:CBC)
      cipher.decrypt
      cipher.key = get_encryption_key(key)
      cipher.iv = encrypted[0..AES_BLOCKSIZE-1]

      cipher.update(encrypted[AES_BLOCKSIZE..encrypted.length]) + cipher.final
    end

    def digest(value)
      Digest::SHA256.hexdigest(value)
    end

    private

    def get_encryption_key(key)
      digest(key)[0..2*AES_BLOCKSIZE-1]
    end
  end
end

