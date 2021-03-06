class ReportsController < ApplicationController
  STATS_DATAFILE_NAME = "stats_%d.yml" unless defined?(STATS_DATAFILE_NAME)
  layout 'report'
  def show
    @pool = Pool.find(params[:id])
    if params[:report] == 'possibility'
      possibility
    end
  end

  def possibility
    pool_id = params[:id]
    my_data_file = self.stats_data_file(pool_id)
    if !File.exist?(my_data_file)
      @message = "The statistics data has not yet been generated.  Please try again later or send an email to #{ADMIN_EMAIL}."
      @stats = []
    else
      @stats = YAML.load_file(my_data_file)
    end
  end

  def gen_possibility
    @pool = Pool.find(params[:id])
    pool = @pool.pool
    reporter = Proc.new do |response, output|
      output.write "Starting to generate possibility statistics for #{pool.tournament_entry.picks.number_of_outcomes} possible outcomes...<br/>\n"
      output.flush
      stats_thread = Thread.new do
        begin
          Thread.current[:stats] = pool.possibility_stats do |percentage, remaining|
            Thread.current[:percentage] = percentage
            Thread.current[:remaining] = remaining
          end
        rescue Exception => e
          Thread.current[:error] = e
          Thread.current[:percentage] = 100
        end
      end

      while stats_thread[:percentage].nil? || stats_thread[:percentage] < 100
        logger.info "   -> #{stats_thread[:percentage] || 'UNK'}% Complete #{stats_thread[:remaining] || 'UNK'}s remaining ... "
        output.write "   -> #{stats_thread[:percentage] || 'UNK'}% Complete #{stats_thread[:remaining] || 'UNK'}s remaining ... <br/>"
        output.flush
        sleep 10
      end

      output.write "Waiting for thread to end ..."
      stats_thread.join

      if stats_thread[:error]
        output.write "Got error #{stats_thread[:error]}"
        output.write "<br/>"
        output.flush
      else
        data = stats_thread[:stats]
        File.open(self.stats_data_file(@pool.id), "w") {|f| f.write YAML.dump(data)}
        output.write "Generated file!"
      end
    end
    render :text => reporter
  end

  def stats_data_file(pool_id)
    File.expand_path(File.join(RAILS_ROOT, 'db', STATS_DATAFILE_NAME % pool_id))
  end

end
