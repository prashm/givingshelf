module ApiCursorPagination
  extend ActiveSupport::Concern

  # Based on https://jsonapi.org/profiles/ethanresnick/cursor-pagination/

  attr_accessor :page_size, :page_before, :page_after,
                # Meta attrs
                :total_size, :total_pages, :next_page_cursor_id, :prev_page_cursor_id

  def validate_and_setup_page_params(page_params)
    @errors ||= []
    self.page_size = 0
    return if page_params.blank?

    self.page_size = page_params[:size].to_i
    if page_size < 1
      @errors << {
        title: "Invalid Parameter.",
        detail: "page[size] is required and must be a positive integer; got #{page_params[:size]}",
        source: { parameter: "page[size]" }
      }
    elsif page_params.has_key?(:sort)
      @errors << {
        title: "Unsupported Sort.",
        detail: "page[sort] is not supported; got page[sort]=#{page_params[:sort]}",
        source: { parameter: "page[sort]" },
        links: { type: [ "https://jsonapi.org/profiles/ethanresnick/cursor-pagination/unsupported-sort" ] }
      }
    elsif page_params.has_key?(:before) && page_params.has_key?(:after)
      @errors << {
        title: "Range Pagination Not Supported.",
        detail: "Range pagination not supported; got page[before]=#{page_params[:before]} and page[after]=#{page_params[:after]}",
        links: { type: [ "https://jsonapi.org/profiles/ethanresnick/cursor-pagination/range-pagination-not-supported" ] }
      }
    elsif page_params.has_key?(:before)
      self.page_before = page_params[:before]
      if self.page_before.blank?
        @errors << {
          title: "Invalid Parameter.",
          detail: "page[before] is invalid",
          source: { parameter: "page[before]" }
        }
      end
    elsif page_params.has_key?(:after)
      self.page_after = page_params[:after]
      if self.page_after.blank?
        @errors << {
          title: "Invalid Parameter.",
          detail: "page[after] is invalid",
          source: { parameter: "page[after]" }
        }
      end
    end
  end

  def paginate(scope, scope_id_str, row_id_str = scope_id_str)
    if page_size > 0
      self.total_size = scope.size
      self.total_pages = total_size / page_size
      self.total_pages += 1 if total_size % page_size > 0

      # :brakeman_ignore SQL
      scope = scope.where("#{scope_id_str} > ?", page_after) if page_after.present?
      # :brakeman_ignore SQL
      scope = scope.where("#{scope_id_str} < ?", page_before) if page_before.present?
      scope = scope.limit(page_size)
      if page_before.present? && page_after.blank?
        # :brakeman_ignore SQL
        scope = scope.order("#{scope_id_str} desc")
        rows = scope.to_a.sort_by { |r| r.send(row_id_str) }
      else
        # :brakeman_ignore SQL
        rows = scope.order(scope_id_str).to_a
      end

      self.next_page_cursor_id = rows.last&.send(row_id_str)
      self.prev_page_cursor_id = rows.first&.send(row_id_str)
      rows
    else
      scope.to_a
    end
  end

  def page_links_and_meta_data(base_url, query_params)
    if page_size > 0
      cursor = {}
      cursor[:before] = prev_page_cursor_id if prev_page_cursor_id.present?
      cursor[:after] = next_page_cursor_id if next_page_cursor_id.present?
      meta_hash = {
        meta: {
          page: { cursor: cursor, total: total_size, pages: total_pages }
        }
      }
      meta_hash[:links] = {}
      if prev_page_cursor_id.present?
        query_string = query_params.merge(page: { before: prev_page_cursor_id, size: page_size }).to_query
        meta_hash[:links].merge!(prev: "#{base_url}?#{query_string}")
      end
      if next_page_cursor_id.present?
        query_string = query_params.merge(page: { after: next_page_cursor_id, size: page_size }).to_query
        meta_hash[:links].merge!(next: "#{base_url}?#{query_string}")
      end
      meta_hash
    else
      {}
    end
  end
end
