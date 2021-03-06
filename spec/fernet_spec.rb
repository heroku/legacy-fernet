require 'spec_helper'
require 'fernet/legacy'

describe Fernet::Legacy do
  after { Fernet::Legacy::Configuration.run }

  let(:token_data) do
    { :email => 'harold@heroku.com', :id => '123', :arbitrary => 'data' }
  end

  let(:secret)     { 'JrdICDH6x3M7duQeM8dJEMK4Y5TkBIsYDw1lPy35RiY=' }
  let(:bad_secret) { 'badICDH6x3M7duQeM8dJEMK4Y5TkBIsYDw1lPy35RiY=' }

  it 'can verify tokens it generates' do
    token = Fernet::Legacy.generate(secret) do |generator|
      generator.data = token_data
    end

    expect(
      Fernet::Legacy.verify(secret, token) do |verifier|
        verifier.data['email'] == 'harold@heroku.com'
      end
    ).to be_true
  end

  it 'fails with a bad secret' do
    token = Fernet::Legacy.generate(secret) do |generator|
      generator.data = token_data
    end

    expect(
      Fernet::Legacy.verify(bad_secret, token) do |verifier|
        verifier.data['email'] == 'harold@heroku.com'
      end
    ).to be_false
  end

  it 'fails with a bad custom verification' do
    token = Fernet::Legacy.generate(secret) do |generator|
      generator.data = { :email => 'harold@heroku.com' }
    end

    expect(
      Fernet::Legacy.verify(secret, token) do |verifier|
        verifier.data['email'] == 'lol@heroku.com'
      end
    ).to be_false
  end

  it 'fails if the token is too old' do
    token = Fernet::Legacy.generate(secret) do |generator|
      generator.data = token_data
    end

    expect(
      Fernet::Legacy.verify(secret, token) do |verifier|
        verifier.ttl = 1

        def verifier.now
          now = DateTime.now
          DateTime.new(now.year, now.month, now.day, now.hour,
                       now.min, now.sec + 2, now.offset)
        end
        true
      end
    ).to be_false
  end

  it 'verifies without a custom verification' do
    token = Fernet::Legacy.generate(secret) do |generator|
      generator.data = token_data
    end

    expect(Fernet::Legacy.verify(secret, token)).to be_true
  end

  it 'can ignore TTL enforcement' do
    token = Fernet::Legacy.generate(secret) do |generator|
      generator.data = token_data
    end

    expect(
      Fernet::Legacy.verify(secret, token) do |verifier|
        def verifier.now
          Time.now + 99999999999
        end
        verifier.enforce_ttl = false
        true
      end
    ).to be_true
  end

  it 'can ignore TTL enforcement via global config' do
    Fernet::Legacy::Configuration.run do |config|
      config.enforce_ttl = false
    end

    token = Fernet::Legacy.generate(secret) do |generator|
      generator.data = token_data
    end

    expect(
      Fernet::Legacy.verify(secret, token) do |verifier|
        def verifier.now
          Time.now + 99999999999
        end
        true
      end
    ).to be_true
  end

  it 'generates without custom data' do
    token = Fernet::Legacy.generate(secret)

    expect(Fernet::Legacy.verify(secret, token)).to be_true
  end

  it 'can encrypt the payload' do
    token = Fernet::Legacy.generate(secret, true) do |generator|
      generator.data['password'] = 'password1'
    end

    expect(Base64.decode64(token)).not_to match /password1/

    Fernet::Legacy.verify(secret, token) do |verifier|
      expect(verifier.data['password']).to eq('password1')
    end
  end

  it 'does not encrypt when asked nicely' do
    token = Fernet::Legacy.generate(secret, false) do |generator|
      generator.data['password'] = 'password1'
    end

    expect(Base64.decode64(token)).to match /password1/

    Fernet::Legacy.verify(secret, token, false) do |verifier|
      expect(verifier.data['password']).to eq('password1')
    end
  end

  it 'can disable encryption via global configuration' do
    Fernet::Legacy::Configuration.run { |c| c.encrypt = false }
    token = Fernet::Legacy.generate(secret) do |generator|
      generator.data['password'] = 'password1'
    end

    expect(Base64.decode64(token)).to match /password1/

    Fernet::Legacy.verify(secret, token) do |verifier|
      expect(verifier.data['password']).to eq('password1')
    end
  end

  it 'returns the unencrypted message upon verify' do
    token = Fernet::Legacy.generate(secret) do |generator|
      generator.data['password'] = 'password1'
    end

    verifier = Fernet::Legacy.verifier(secret, token)
    expect(verifier.valid?).to be_true
    expect(verifier.data['password']).to eq('password1')
  end
end
