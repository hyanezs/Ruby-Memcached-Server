# frozen_string_literal: true

require 'validate_protocol'

describe 'ValidateProtocol' do
  ##########################################################

  context 'length validation' do
    it 'should validate "set 0 0 0 0"' do
      validation = ValidateProtocol.validate(%w[set 0 0 0 0], false, false)
      expect(validation[1]).to(equal(true))
    end
    it 'should not validate "set 0 0 0 0 0"' do
      validation = ValidateProtocol.validate(%w[set 0 0 0 0 0], false, false)
      expect(validation[1]).to(equal(false))
    end
    it 'should not validate "set 0 0 0"' do
      validation = ValidateProtocol.validate(%w[set 0 0 0], false, false)
      expect(validation[1]).to(equal(false))
    end
    it 'should not validate "set"' do
      validation = ValidateProtocol.validate(%w[set], false, false)
      expect(validation[1]).to(equal(false))
    end
    it 'should validate "set 0 0 0 0 noreply"' do
      validation = ValidateProtocol.validate(%w[set 0 0 0 0 noreply], true, false)
      expect(validation[1]).to(equal(true))
    end
    it 'should not validate "set 0 0 0 noreply"' do
      validation = ValidateProtocol.validate(%w[set 0 0 0 noreply], true, false)
      expect(validation[1]).to(equal(false))
    end
    it 'should not validate "set 0 0 0 noreply 0"' do
      validation = ValidateProtocol.validate(%w[set 0 0 0 noreply], false, false)
      expect(validation[1]).to(equal(false))
    end
  end

  ###############################

  context 'key validation' do
    it 'should not validate key longer than 250 char' do
      validation = ValidateProtocol.validate(
        %w[
          set
          thisisalooooooongkeythisisalooooooongkeythisisalooooooongkeythisisalooooooongkeythisisalooooooongkeythisisalooooooongkeythisisalooooooongkeythisisalooooooongkeythisisalooooooongkeythisisalooooooongkeythisisalooooooongkeythisisalooooooongkeythisisalooooooongkey
          0
          0
          0
        ],
        false,
        false
      )
      expect(validation[1]).to(equal(false))
    end
    it 'should not validate key with control char' do
      validation = ValidateProtocol.validate(%w[set \b\n 0 0 0], false, false)
      expect(validation[1]).to(equal(false))
    end
    it 'should validate "key"' do
      validation = ValidateProtocol.validate(%w[set key 0 0 0], false, false)
      expect(validation[1]).to(equal(true))
    end
    it 'should validate "21311"' do
      validation = ValidateProtocol.validate(%w[set 21311 0 0 0], false, false)
      expect(validation[1]).to(equal(true))
    end
  end

  ###############################

  context 'flags validation' do
    it 'should not validate NaN flag' do
      validation = ValidateProtocol.validate(%w[set key flag 0 0], false, false)
      expect(validation[1]).to(equal(false))
    end
    it 'should not validate numbers and chars flag' do
      validation = ValidateProtocol.validate(%w[set key 1a2 0 0], false, false)
      expect(validation[1]).to(equal(false))
    end
    it 'should not validate negative flag' do
      validation = ValidateProtocol.validate(%w[set key -1 0 0], false, false)
      expect(validation[1]).to(equal(false))
    end
    it 'should not validate unsigned integer bigger than 16bits flag (decimal)' do
      validation = ValidateProtocol.validate(%w[set key 70000 0 0], false, false)
      expect(validation[1]).to(equal(false))
    end
    it 'should validate unsigned integer flag smaller than 16bits' do
      validation = ValidateProtocol.validate(%w[set key 16000 0 0], false, false)
      expect(validation[1]).to(equal(true))
    end
  end

  ###############################

  context 'exptime validation' do
    it 'should not validate NaN exptime' do
      validation = ValidateProtocol.validate(%w[set key 0 exptime 0], false, false)
      expect(validation[1]).to(equal(false))
    end
    it 'should not validate numbers and chars exptime' do
      validation = ValidateProtocol.validate(%w[set key 0 1a2 0], false, false)
      expect(validation[1]).to(equal(false))
    end
    it 'should validate negative exptime' do
      validation = ValidateProtocol.validate(%w[set key 0 -1 0], false, false)
      expect(validation[1]).to(equal(true))
    end
    it 'should validate positive exptime' do
      validation = ValidateProtocol.validate(%w[set key 0 1 0], false, false)
      expect(validation[1]).to(equal(true))
    end
  end

  ###############################

  context 'bytes validation' do
    it 'should not validate NaN bytes' do
      validation = ValidateProtocol.validate(%w[set key 0 0 bytes], false, false)
      expect(validation[1]).to(equal(false))
    end
    it 'should not validate numbers and chars bytes' do
      validation = ValidateProtocol.validate(%w[set key 0 0 1a2], false, false)
      expect(validation[1]).to(equal(false))
    end
    it 'should not validate negative bytes' do
      validation = ValidateProtocol.validate(%w[set key 0 0 -1], false, false)
      expect(validation[1]).to(equal(false))
    end
    it 'should validate positive bytes' do
      validation = ValidateProtocol.validate(%w[set key 0 0 10], false, false)
      expect(validation[1]).to(equal(true))
    end
  end

  ###############################

  context 'cas_unique validation' do
    it 'should not validate NaN cas_unique' do
      validation = ValidateProtocol.validate(%w[cas key 0 0 0 cas_unique], false, false)
      expect(validation[1]).to(equal(false))
    end
    it 'should not validate numbers and chars cas_unique' do
      validation = ValidateProtocol.validate(%w[cas key 0 0 0 12cas_unique12], false, false)
      expect(validation[1]).to(equal(false))
    end
    it 'should not validate negative cas_unique' do
      validation = ValidateProtocol.validate(%w[cas key 0 0 0 -123], false, false)
      expect(validation[1]).to(equal(false))
    end
    it 'should validate positive bytes' do
      validation = ValidateProtocol.validate(%w[cas key 0 0 0 123], false, false)
      expect(validation[1]).to(equal(true))
    end
  end

  ###############################

  context 'multiple validations' do
    it 'should not validate "set key a 12 -1 noreply"' do
      validation = ValidateProtocol.validate(%w[set key a 12 -1 noreply], true, false)
      expect(validation[1]).to(equal(false))
    end
    it 'should not validate "set key 123456 12 0 noreply"' do
      validation = ValidateProtocol.validate(%w[set key 123456 12 0 noreply], true, false)
      expect(validation[1]).to(equal(false))
    end
    it 'should validate "set key 12345 12 0 noreply"' do
      validation = ValidateProtocol.validate(%w[set key 12345 12 0 noreply], true, false)
      expect(validation[1]).to(equal(true))
    end
    it 'should validate "set key 12345 -12 23 noreply"' do
      validation = ValidateProtocol.validate(%w[set key 12345 -12 23 noreply], true, false)
      expect(validation[1]).to(equal(true))
    end
    it 'should validate "set key 12345 12 0"' do
      validation = ValidateProtocol.validate(%w[set key 12345 12 0], false, false)
      expect(validation[1]).to(equal(true))
    end
  end
end
