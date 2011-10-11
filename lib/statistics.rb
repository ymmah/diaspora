require 'statsample'

class Statistics

  attr_reader :start_time,
              :range

  def initialize
    #@start_time = start_time
    #@range = range
  end

  def posts_count_sql
    <<SQL
      SELECT users.id AS id, count(posts.id) AS count
        FROM users
          JOIN people ON people.owner_id = users.id
          LEFT OUTER JOIN posts ON people.id = posts.author_id
          GROUP BY users.id
SQL
  end

  def invites_sent_count_sql
    <<SQL
      SELECT users.id AS id, count(invitations.id) AS count
        FROM users
          LEFT OUTER JOIN invitations ON users.id = invitations.sender_id
          GROUP BY users.id
SQL
  end

  def tags_followed_count_sql
    <<SQL
      SELECT users.id AS id, count(tag_followings.id) AS count
        FROM users
          LEFT OUTER JOIN tag_followings on users.id = tag_followings.user_id
          GROUP BY users.id
SQL
  end

  def mentions_count_sql
    <<SQL
      SELECT users.id AS id, count(mentions.id) AS count
        FROM users
          JOIN people on users.id = people.owner_id
          LEFT OUTER JOIN mentions on people.id = mentions.person_id
          GROUP BY users.id
SQL
  end

  def sign_in_count_sql
    <<SQL
      SELECT users.id AS id, users.sign_in_count AS count
        FROM users
SQL
  end

  def correlate(first_metric, second_metric)

    # [{"id" => 1 , "count" => 123}]

    x_array = []
    y_array = []

    self.result_hash(first_metric).keys.each do |k| 
      if val = self.result_hash(second_metric)[k]
        x_array << self.result_hash(first_metric)[k]
        y_array << val
      end
    end

    correlation(x_array, y_array)
  end

  def generate_correlations
    result = {}
    [:posts_count, :invites_sent_count, :tags_followed_count,
     :mentions_count].each do |metric|
      result[metric] = self.correlate(metric,:sign_in_count)
     end
    result
  end
  

  def correlation(x_array, y_array)
    x = x_array.to_scale
    y = y_array.to_scale
    pearson = Statsample::Bivariate::Pearson.new(x,y)
    pearson.r
  end

  ### % of cohort came back last week
  def retention(n)
    week_created(n).where("current_sign_in_at > ?", Time.now - 1.week).count.to_f/week_created(n).count
  end

  protected
  def week_created(n)
    User.where("username IS NOT NULL").where("created_at > ? and created_at < ?", Time.now - (n+1).weeks, Time.now - n.weeks)
  end

  #@param [Symbol] input type
  #@returns [Hash] of resulting query
  def result_hash(type)
    instance_hash = self.instance_variable_get("@#{type.to_s}_hash".to_sym)
    unless instance_hash
      post_count_array = User.connection.select_all(self.send("#{type.to_s}_sql".to_sym))

      instance_hash = {}
      post_count_array.each{ |h| instance_hash[h['id']] = h["count"]}
      self.instance_variable_set("@#{type.to_s}_hash".to_sym, instance_hash)
    end
    instance_hash
  end
end
