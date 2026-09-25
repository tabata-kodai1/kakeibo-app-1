# バリデーションエラーなど、リクエストの誤りを 400 で返すための例外。
# errors は項目名 => メッセージ。項目に紐づかないエラーなら省略する
class Api::BadRequest < StandardError
  attr_reader :errors

  def initialize(message, errors: nil)
    super(message)
    @errors = errors
  end
end
