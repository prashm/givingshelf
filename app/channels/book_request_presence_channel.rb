require "set"

class BookRequestPresenceChannel < ApplicationCable::Channel
  REDIS_KEY_PREFIX = "book_request_presence"
  PRESENCE_TTL = 300 # 5 minutes - users are considered inactive after this

  # Fallback in-memory store for development when Redis is unavailable
  @@fallback_active_users = {} # book_request_id => Set of user_ids
  @@redis_available = nil

  def subscribed
    @book_request = ItemRequest.find(params[:book_request_id])

    unless can_access_chat?
      reject
      return
    end

    stream_from "book_request_presence_#{params[:book_request_id]}"

    # Track this user as active in Redis
    track_user_active

    # Broadcast that this user is now active
    broadcast_presence_update
  end

  def unsubscribed
    # Remove this user from active tracking in Redis
    untrack_user_active

    # Broadcast that this user is no longer active
    broadcast_presence_update
  end

  def heartbeat
    # Backup heartbeat mechanism - refresh TTL if user is still active
    if can_access_chat?
      track_user_active
    end
  end

  def self.is_user_active?(book_request_id, user_id)
    if redis_available?
      redis_key = "#{REDIS_KEY_PREFIX}:#{book_request_id}"
      redis_connection.sismember(redis_key, user_id.to_s)
    else
      # Fallback to in-memory store
      @@fallback_active_users[book_request_id.to_i]&.include?(user_id.to_i) || false
    end
  end

  private

  def can_access_chat?
    return false unless current_user
    @book_request.requester == current_user || @book_request.owner == current_user
  end

  def track_user_active
    if redis_available?
      redis_key = "#{REDIS_KEY_PREFIX}:#{@book_request.id}"
      redis_connection.sadd(redis_key, current_user.id.to_s)
      redis_connection.expire(redis_key, PRESENCE_TTL)
    else
      # Fallback to in-memory store
      @@fallback_active_users[@book_request.id] ||= Set.new
      @@fallback_active_users[@book_request.id].add(current_user.id)
    end
  end

  def untrack_user_active
    if redis_available?
      redis_key = "#{REDIS_KEY_PREFIX}:#{@book_request.id}"
      redis_connection.srem(redis_key, current_user.id.to_s)
    else
      # Fallback to in-memory store
      @@fallback_active_users[@book_request.id]&.delete(current_user.id)
      @@fallback_active_users.delete(@book_request.id) if @@fallback_active_users[@book_request.id]&.empty?
    end
  end

  def broadcast_presence_update
    # Get all active users for this book request
    active_user_ids = if redis_available?
      redis_key = "#{REDIS_KEY_PREFIX}:#{@book_request.id}"
      redis_connection.smembers(redis_key).map(&:to_i)
    else
      # Fallback to in-memory store
      (@@fallback_active_users[@book_request.id] || Set.new).to_a
    end

    active_users = User.where(id: active_user_ids)

    ActionCable.server.broadcast(
      "book_request_presence_#{params[:book_request_id]}",
      {
        type: "presence",
        users: active_users.map { |user| { id: user.id, name: user.display_name } }
      }
    )
  end

  def redis_connection
    @redis_connection ||= begin
      redis_url = get_redis_url
      Redis.new(url: redis_url)
    rescue Redis::CannotConnectError => e
      Rails.logger.warn "Redis connection failed: #{e.message}. Using in-memory fallback for presence tracking."
      mark_redis_unavailable
      nil
    end
  end

  def self.redis_connection
    @redis_connection ||= begin
      redis_url = get_redis_url
      Redis.new(url: redis_url)
    rescue Redis::CannotConnectError => e
      Rails.logger.warn "Redis connection failed: #{e.message}. Using in-memory fallback for presence tracking."
      mark_redis_unavailable
      nil
    end
  end

  def redis_available?
    self.class.redis_available?
  end

  def self.redis_available?
    return @@redis_available unless @@redis_available.nil?

    # Test Redis connection
    begin
      redis_url = get_redis_url
      test_conn = Redis.new(url: redis_url)
      test_conn.ping
      test_conn.quit
      @@redis_available = true
    rescue => e
      Rails.logger.warn "Redis check failed: #{e.message}. Using in-memory fallback."
      @@redis_available = false
    end

    @@redis_available
  end

  def self.mark_redis_unavailable
    @@redis_available = false
  end

  def self.get_redis_url
    # Try to get from ActionCable config first
    cable_config = ActionCable.server.config.cable rescue nil
    if cable_config && cable_config[:url]
      return cable_config[:url]
    end

    # Fallback to environment variable or default
    if Rails.env.production?
      ENV.fetch("REDIS_URL", "redis://localhost:6379/1")
    else
      ENV.fetch("REDIS_URL", "redis://localhost:6379/1")
    end
  end

  def get_redis_url
    self.class.get_redis_url
  end
end
