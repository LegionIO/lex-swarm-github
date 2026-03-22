# frozen_string_literal: true

module Legion
  module Extensions
    module SwarmGithub
      module Helpers
        module DiffChunker
          DEFAULT_MAX_CHARS = 12_000

          module_function

          def chunk_files(files, max_chars: DEFAULT_MAX_CHARS)
            files = files.select { |f| f[:patch] && !f[:patch].empty? }
            return [] if files.empty?

            chunks = []
            current_chunk = []
            current_size = 0

            files.each do |file|
              patch = file[:patch]
              patch = patch[0, max_chars] if patch.length > max_chars
              entry = { filename: file[:filename], patch: patch }

              if current_size + patch.length > max_chars && !current_chunk.empty?
                chunks << current_chunk
                current_chunk = []
                current_size = 0
              end

              current_chunk << entry
              current_size += patch.length
            end

            chunks << current_chunk unless current_chunk.empty?
            chunks
          end
        end
      end
    end
  end
end
