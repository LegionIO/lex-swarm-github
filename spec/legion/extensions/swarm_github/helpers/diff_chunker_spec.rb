# frozen_string_literal: true

require 'spec_helper'
require 'legion/extensions/swarm_github/helpers/diff_chunker'

RSpec.describe Legion::Extensions::SwarmGithub::Helpers::DiffChunker do
  describe '.chunk_files' do
    let(:small_file) { { filename: 'a.rb', patch: '+ line1' } }
    let(:large_patch) { "+ #{'x' * 6000}" }
    let(:large_file) { { filename: 'b.rb', patch: large_patch } }

    it 'returns a single chunk when files fit within limit' do
      chunks = described_class.chunk_files([small_file], max_chars: 4000)
      expect(chunks.size).to eq(1)
      expect(chunks.first.size).to eq(1)
      expect(chunks.first.first[:filename]).to eq('a.rb')
    end

    it 'splits files into multiple chunks when total exceeds limit' do
      files = [small_file, large_file]
      chunks = described_class.chunk_files(files, max_chars: 4000)
      expect(chunks.size).to eq(2)
    end

    it 'truncates a single file patch that exceeds the limit' do
      chunks = described_class.chunk_files([large_file], max_chars: 1000)
      expect(chunks.size).to eq(1)
      expect(chunks.first.first[:patch].length).to be <= 1000
    end

    it 'preserves filename in each chunk entry' do
      chunks = described_class.chunk_files([small_file, large_file], max_chars: 4000)
      all_files = chunks.flatten.map { |f| f[:filename] }
      expect(all_files).to include('a.rb', 'b.rb')
    end

    it 'uses default max_chars of 12000' do
      files = Array.new(5) { |i| { filename: "f#{i}.rb", patch: "+ #{'y' * 3000}" } }
      chunks = described_class.chunk_files(files)
      expect(chunks.size).to be > 1
    end

    it 'handles empty file list' do
      chunks = described_class.chunk_files([])
      expect(chunks).to eq([])
    end

    it 'skips files with nil patch' do
      nil_patch = { filename: 'binary.png', patch: nil }
      chunks = described_class.chunk_files([nil_patch, small_file])
      all_files = chunks.flatten.map { |f| f[:filename] }
      expect(all_files).not_to include('binary.png')
      expect(all_files).to include('a.rb')
    end
  end
end
