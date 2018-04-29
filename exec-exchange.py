import exchanges.py

# This module executes an external process that is expected to output
# JSON. This way you can incorporate just about any method of ingest
# of coin data

class ExternalExchange(BaseExchange):
    def __init__(self, program_file, exchange_name):
        super().__init__()
        self.name = exchange_name
        self._get_all_rates()

    def _get_all_rates(self):
        raw_data = requests.get(self.url).json()
        for x in raw_data:
            self.rate_for[x['symbol']] = x['price_usd']
