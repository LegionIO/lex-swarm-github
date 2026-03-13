# frozen_string_literal: true

require 'legion/extensions/swarm_github/client'

RSpec.describe Legion::Extensions::SwarmGithub::Runners::GithubSwarm do
  let(:client) { Legion::Extensions::SwarmGithub::Client.new }

  describe '#ingest_issue' do
    it 'tracks a GitHub issue' do
      result = client.ingest_issue(repo: 'org/repo', issue_number: 42, title: 'Bug fix needed')
      expect(result[:tracked]).to be true
      expect(result[:state]).to eq(:received)
    end
  end

  describe '#claim_issue' do
    it 'transitions issue to found state' do
      client.ingest_issue(repo: 'org/repo', issue_number: 1, title: 'test')
      result = client.claim_issue(key: 'org/repo#1')
      expect(result[:claimed]).to be true
    end
  end

  describe '#start_fix' do
    it 'starts a fix attempt' do
      client.ingest_issue(repo: 'org/repo', issue_number: 1, title: 'test')
      client.claim_issue(key: 'org/repo#1')
      result = client.start_fix(key: 'org/repo#1')
      expect(result[:fixing]).to be true
      expect(result[:attempt]).to eq(1)
    end

    it 'rejects after max attempts' do
      client.ingest_issue(repo: 'org/repo', issue_number: 1, title: 'test')
      4.times { client.start_fix(key: 'org/repo#1') }
      result = client.start_fix(key: 'org/repo#1')
      expect(result[:error]).to eq(:max_attempts_exceeded)
    end
  end

  describe '#submit_validation' do
    it 'records validation' do
      client.ingest_issue(repo: 'org/repo', issue_number: 1, title: 'test')
      result = client.submit_validation(key: 'org/repo#1', validator: 'v1', approved: true)
      expect(result[:recorded]).to be true
    end

    it 'reaches consensus with k=3 approvals' do
      client.ingest_issue(repo: 'org/repo', issue_number: 1, title: 'test')
      client.submit_validation(key: 'org/repo#1', validator: 'v1', approved: true)
      client.submit_validation(key: 'org/repo#1', validator: 'v2', approved: true)
      result = client.submit_validation(key: 'org/repo#1', validator: 'v3', approved: true)
      expect(result[:consensus]).to eq(:approved)
    end
  end

  describe '#attach_pr' do
    it 'attaches a PR to the issue' do
      client.ingest_issue(repo: 'org/repo', issue_number: 1, title: 'test')
      result = client.attach_pr(key: 'org/repo#1', pr_number: 100)
      expect(result[:attached]).to be true
    end
  end

  describe '#pipeline_status' do
    it 'returns counts by state' do
      client.ingest_issue(repo: 'org/repo', issue_number: 1, title: 'test1')
      client.ingest_issue(repo: 'org/repo', issue_number: 2, title: 'test2')
      status = client.pipeline_status
      expect(status[:total]).to eq(2)
      expect(status[:states][:received]).to eq(2)
    end
  end
end
