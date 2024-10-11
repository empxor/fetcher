# fetcher
 A Ruby CLI tool for troubleshooting what some ATProto PDS media blobs were returning when fetched

## Usage

`ruby fetcher.rb -k <record_key> [-u <username>] [-p <password>] [-s <server>]`

`DEFAULT_CONFIG` can be set within the script, so the only required flag is `-k`

```ruby
DEFAULT_CONFIG = {
  server: 'PDS server',
  username: 'PDS username',
  password: 'PDS password',
  key: 'record-key'
}
```

