# frozen_string_literal: true

RSpec.describe Legion::Extensions::SwarmGithub::Helpers::Pipeline do
  describe 'constants' do
    it 'defines STATES as the eight pipeline states' do
      expect(described_class::STATES).to eq(%i[received found fixing validating approved pr_open rejected stale])
    end

    it 'defines LABELS derived from STATES with swarm: prefix' do
      expected = described_class::STATES.map { |s| :"swarm:#{s}" }
      expect(described_class::LABELS).to eq(expected)
    end

    it 'defines PIPELINE_ROLES as the four agent roles' do
      expect(described_class::PIPELINE_ROLES).to eq(%i[finder fixer validator pr_swarm])
    end

    it 'defines ADVERSARIAL_REVIEW_K as 3' do
      expect(described_class::ADVERSARIAL_REVIEW_K).to eq(3)
    end

    it 'defines MAX_FIX_ATTEMPTS as 3' do
      expect(described_class::MAX_FIX_ATTEMPTS).to eq(3)
    end

    it 'defines STALE_TIMEOUT as 86400' do
      expect(described_class::STALE_TIMEOUT).to eq(86_400)
    end
  end

  describe '.valid_state?' do
    it 'returns true for all defined STATES' do
      described_class::STATES.each do |state|
        expect(described_class.valid_state?(state)).to be true
      end
    end

    it 'returns true for :received' do
      expect(described_class.valid_state?(:received)).to be true
    end

    it 'returns true for :stale' do
      expect(described_class.valid_state?(:stale)).to be true
    end

    it 'returns true for :pr_open' do
      expect(described_class.valid_state?(:pr_open)).to be true
    end

    it 'returns false for an unknown state' do
      expect(described_class.valid_state?(:pending)).to be false
    end

    it 'returns false for nil' do
      expect(described_class.valid_state?(nil)).to be false
    end

    it 'returns false for a string version of a valid state' do
      expect(described_class.valid_state?('received')).to be false
    end
  end

  describe '.label_for_state' do
    it 'returns swarm:received for :received' do
      expect(described_class.label_for_state(:received)).to eq('swarm:received')
    end

    it 'returns swarm:fixing for :fixing' do
      expect(described_class.label_for_state(:fixing)).to eq('swarm:fixing')
    end

    it 'returns swarm:pr_open for :pr_open' do
      expect(described_class.label_for_state(:pr_open)).to eq('swarm:pr_open')
    end

    it 'returns a string result for every defined state' do
      described_class::STATES.each do |state|
        expect(described_class.label_for_state(state)).to eq("swarm:#{state}")
      end
    end
  end

  describe '.next_state' do
    it 'returns :found for :received' do
      expect(described_class.next_state(:received)).to eq(:found)
    end

    it 'returns :fixing for :found' do
      expect(described_class.next_state(:found)).to eq(:fixing)
    end

    it 'returns :validating for :fixing' do
      expect(described_class.next_state(:fixing)).to eq(:validating)
    end

    it 'returns :approved for :validating' do
      expect(described_class.next_state(:validating)).to eq(:approved)
    end

    it 'returns :pr_open for :approved' do
      expect(described_class.next_state(:approved)).to eq(:pr_open)
    end

    it 'returns nil for terminal states with no next state' do
      expect(described_class.next_state(:pr_open)).to be_nil
      expect(described_class.next_state(:rejected)).to be_nil
      expect(described_class.next_state(:stale)).to be_nil
    end

    it 'returns nil for an unknown state' do
      expect(described_class.next_state(:unknown)).to be_nil
    end
  end
end
