# frozen_string_literal: true

RSpec.describe Legion::Extensions::SwarmGithub::Helpers::IssueTracker do
  let(:tracker) { described_class.new }
  let(:pipeline) { Legion::Extensions::SwarmGithub::Helpers::Pipeline }

  let(:repo) { 'org/repo' }
  let(:issue_number) { 42 }
  let(:key) { "#{repo}##{issue_number}" }

  before { tracker.track(repo: repo, issue_number: issue_number, title: 'Fix the bug') }

  describe '#initialize' do
    it 'starts with an empty issues hash' do
      expect(described_class.new.issues).to eq({})
    end
  end

  describe '#track' do
    it 'returns the composite key' do
      k = described_class.new.track(repo: 'a/b', issue_number: 1, title: 'test')
      expect(k).to eq('a/b#1')
    end

    it 'stores the issue under the composite key' do
      expect(tracker.issues[key]).not_to be_nil
    end

    it 'sets initial state to :received' do
      expect(tracker.issues[key][:state]).to eq(:received)
    end

    it 'stores the repo' do
      expect(tracker.issues[key][:repo]).to eq(repo)
    end

    it 'stores the issue_number' do
      expect(tracker.issues[key][:issue_number]).to eq(issue_number)
    end

    it 'stores the title' do
      expect(tracker.issues[key][:title]).to eq('Fix the bug')
    end

    it 'starts fix_attempts at 0' do
      expect(tracker.issues[key][:fix_attempts]).to eq(0)
    end

    it 'starts with an empty validations array' do
      expect(tracker.issues[key][:validations]).to eq([])
    end

    it 'starts with pr_number nil' do
      expect(tracker.issues[key][:pr_number]).to be_nil
    end

    it 'stores provided labels' do
      t = described_class.new
      t.track(repo: 'a/b', issue_number: 1, title: 'test', labels: %w[bug critical])
      expect(t.issues['a/b#1'][:labels]).to eq(%w[bug critical])
    end

    it 'defaults labels to empty array' do
      expect(tracker.issues[key][:labels]).to eq([])
    end

    it 'records created_at as a UTC Time' do
      before = Time.now.utc
      t = described_class.new
      t.track(repo: 'a/b', issue_number: 1, title: 'test')
      after = Time.now.utc
      expect(t.issues['a/b#1'][:created_at]).to be_between(before, after)
    end

    it 'records updated_at as a UTC Time on creation' do
      expect(tracker.issues[key][:updated_at]).not_to be_nil
    end
  end

  describe '#transition' do
    it 'returns the new state when valid' do
      result = tracker.transition(key, :found)
      expect(result).to eq(:found)
    end

    it 'updates the issue state' do
      tracker.transition(key, :found)
      expect(tracker.issues[key][:state]).to eq(:found)
    end

    it 'updates the labels array to the single swarm label for the new state' do
      tracker.transition(key, :found)
      expect(tracker.issues[key][:labels]).to eq([pipeline.label_for_state(:found)])
    end

    it 'updates updated_at on transition' do
      before = Time.now.utc
      tracker.transition(key, :found)
      after = Time.now.utc
      expect(tracker.issues[key][:updated_at]).to be_between(before, after)
    end

    it 'returns :invalid_state for an unknown state symbol' do
      expect(tracker.transition(key, :nonexistent)).to eq(:invalid_state)
    end

    it 'returns nil for an unknown issue key' do
      expect(tracker.transition('bad/key#99', :found)).to be_nil
    end

    it 'can transition through multiple valid states' do
      tracker.transition(key, :found)
      tracker.transition(key, :fixing)
      expect(tracker.issues[key][:state]).to eq(:fixing)
    end
  end

  describe '#record_fix_attempt' do
    it 'returns 1 on the first attempt' do
      expect(tracker.record_fix_attempt(key)).to eq(1)
    end

    it 'increments fix_attempts on the issue' do
      tracker.record_fix_attempt(key)
      expect(tracker.issues[key][:fix_attempts]).to eq(1)
    end

    it 'returns the running total after multiple calls' do
      tracker.record_fix_attempt(key)
      tracker.record_fix_attempt(key)
      expect(tracker.record_fix_attempt(key)).to eq(3)
    end

    it 'returns nil for an unknown key' do
      expect(tracker.record_fix_attempt('bad/key#0')).to be_nil
    end
  end

  describe '#record_validation' do
    it 'appends the validation to the validations array' do
      tracker.record_validation(key, validator: 'v1', approved: true)
      expect(tracker.issues[key][:validations].size).to eq(1)
    end

    it 'stores the validator identifier' do
      tracker.record_validation(key, validator: 'v1', approved: true)
      expect(tracker.issues[key][:validations].first[:validator]).to eq('v1')
    end

    it 'stores the approved flag' do
      tracker.record_validation(key, validator: 'v1', approved: false)
      expect(tracker.issues[key][:validations].first[:approved]).to be false
    end

    it 'stores an optional reason' do
      tracker.record_validation(key, validator: 'v1', approved: false, reason: 'needs more tests')
      expect(tracker.issues[key][:validations].first[:reason]).to eq('needs more tests')
    end

    it 'stores nil for reason when not provided' do
      tracker.record_validation(key, validator: 'v1', approved: true)
      expect(tracker.issues[key][:validations].first[:reason]).to be_nil
    end

    it 'records a timestamp on each validation' do
      before = Time.now.utc
      tracker.record_validation(key, validator: 'v1', approved: true)
      after = Time.now.utc
      expect(tracker.issues[key][:validations].first[:at]).to be_between(before, after)
    end

    it 'returns :pending when fewer than ADVERSARIAL_REVIEW_K approvals exist' do
      tracker.record_validation(key, validator: 'v1', approved: true)
      result = tracker.record_validation(key, validator: 'v2', approved: true)
      expect(result).to eq(:pending)
    end

    it 'returns :approved when ADVERSARIAL_REVIEW_K approvals are reached' do
      tracker.record_validation(key, validator: 'v1', approved: true)
      tracker.record_validation(key, validator: 'v2', approved: true)
      result = tracker.record_validation(key, validator: 'v3', approved: true)
      expect(result).to eq(:approved)
    end

    it 'returns :rejected when ADVERSARIAL_REVIEW_K rejections are reached' do
      tracker.record_validation(key, validator: 'v1', approved: false)
      tracker.record_validation(key, validator: 'v2', approved: false)
      result = tracker.record_validation(key, validator: 'v3', approved: false)
      expect(result).to eq(:rejected)
    end

    it 'returns :pending when approvals and rejections are mixed below threshold' do
      tracker.record_validation(key, validator: 'v1', approved: true)
      result = tracker.record_validation(key, validator: 'v2', approved: false)
      expect(result).to eq(:pending)
    end

    it 'returns nil for an unknown key' do
      expect(tracker.record_validation('bad/key#0', validator: 'v1', approved: true)).to be_nil
    end
  end

  describe '#attach_pr' do
    it 'sets the pr_number on the issue' do
      tracker.attach_pr(key, pr_number: 100)
      expect(tracker.issues[key][:pr_number]).to eq(100)
    end

    it 'transitions state to :pr_open' do
      tracker.attach_pr(key, pr_number: 100)
      expect(tracker.issues[key][:state]).to eq(:pr_open)
    end

    it 'updates updated_at' do
      before = Time.now.utc
      tracker.attach_pr(key, pr_number: 100)
      after = Time.now.utc
      expect(tracker.issues[key][:updated_at]).to be_between(before, after)
    end

    it 'returns nil for an unknown key' do
      expect(tracker.attach_pr('bad/key#0', pr_number: 1)).to be_nil
    end
  end

  describe '#get' do
    it 'returns the issue hash for a known key' do
      result = tracker.get(key)
      expect(result[:title]).to eq('Fix the bug')
    end

    it 'returns nil for an unknown key' do
      expect(tracker.get('unknown/repo#999')).to be_nil
    end
  end

  describe '#by_state' do
    it 'returns all issues in the given state' do
      tracker.track(repo: 'a/b', issue_number: 1, title: 'other')
      results = tracker.by_state(:received)
      expect(results.size).to eq(2)
    end

    it 'excludes issues not in the given state' do
      tracker.transition(key, :found)
      results = tracker.by_state(:received)
      expect(results).to be_empty
    end

    it 'returns an empty array when no issues match' do
      expect(tracker.by_state(:approved)).to eq([])
    end

    it 'reflects state changes after transitions' do
      tracker.transition(key, :found)
      expect(tracker.by_state(:found).size).to eq(1)
    end
  end

  describe '#count' do
    it 'returns 0 for an empty tracker' do
      expect(described_class.new.count).to eq(0)
    end

    it 'returns the number of tracked issues' do
      expect(tracker.count).to eq(1)
    end

    it 'increments when additional issues are tracked' do
      tracker.track(repo: 'a/b', issue_number: 2, title: 'another')
      expect(tracker.count).to eq(2)
    end
  end
end
