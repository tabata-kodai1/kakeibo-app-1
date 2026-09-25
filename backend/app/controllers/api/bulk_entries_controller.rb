# 一括更新・一括削除（F-09）。
#
# update_all / delete_all はモデルのバリデーションと updated_at の自動更新を通らない。
# 単体編集ならモデルで済む検証（日付・カテゴリの存在・収支区分）を、ここで事前にすべて行う。
#
# 判定の順序は「入力の形式（400）→ 対象の存在（404）→ 収支区分（400）」。
# どこで止まっても 1 件も更新・削除しない（docs/features.md F-09「判定の順序」）
class Api::BulkEntriesController < Api::BaseController
  IDS_LIMIT = 500
  ID_FORMAT = /\A\d+\z/
  CROSS_TYPE_MESSAGE = "支出と収入をまたぐカテゴリ変更はできません".freeze

  def update
    ids = target_ids
    changes = update_changes

    @updated_count = Entry.transaction do
      lock_existing!(ids)
      verify_same_category_type!(ids, changes[:category_id]) if changes.key?(:category_id)
      Entry.where(id: ids).update_all(changes.merge(updated_at: Time.current))
    end
  end

  def destroy
    ids = target_ids

    # destroy_all は件数ぶん DELETE を発行する。1 文で消す
    @deleted_count = Entry.transaction do
      lock_existing!(ids)
      Entry.where(id: ids).delete_all
    end
  end

  private

  # 重複は除いて数える。500 件の判定も、除いた件数による
  def target_ids
    raw = params[:ids]
    bad_ids("対象のレコードを選択してください") if raw.blank?
    bad_ids("対象のレコードの指定が不正です") unless raw.is_a?(Array) && raw.all? { |id| valid_id?(id) }

    ids = raw.map { |id| Integer(id.to_s, 10) }.uniq
    bad_ids("一度に操作できるのは#{IDS_LIMIT}件までです") if ids.size > IDS_LIMIT
    ids
  end

  def valid_id?(id)
    (id.is_a?(Integer) && id >= 0) || (id.is_a?(String) && id.match?(ID_FORMAT))
  end

  def bad_ids(message)
    raise Api::BadRequest.new(message, errors: { ids: message })
  end

  # category_id / entry_date は、キーがあれば指定したものとして検証する（null や空文字は未指定ではなく不正）
  def update_changes
    raise Api::BadRequest, "変更する項目を指定してください" unless params.key?(:category_id) || params.key?(:entry_date)

    changes = {}
    errors = {}

    if params.key?(:category_id)
      category = find_category(params[:category_id])
      category ? changes[:category_id] = category.id : errors[:category_id] = "カテゴリを選択してください"
    end
    if params.key?(:entry_date)
      date = DateParam.parse(params[:entry_date])
      date ? changes[:entry_date] = date : errors[:entry_date] = "日付を入力してください"
    end

    raise Api::BadRequest.new(errors.values.first, errors: errors) if errors.any?

    changes
  end

  def find_category(id)
    Category.find_by(id: id) if valid_id?(id)
  end

  # 対象の存在確認。行をロックして、確認から更新・削除までの間に消えないようにする。
  # 1 件でも存在しなければ 404
  def lock_existing!(ids)
    raise ActiveRecord::RecordNotFound if Entry.where(id: ids).lock.pluck(:id).size != ids.size
  end

  # 選択行の収支区分がすべて、変更後のカテゴリと同じでなければ 400
  def verify_same_category_type!(ids, category_id)
    current_types = Entry.where(id: ids).joins(:category).distinct.pluck("categories.category_type")
    new_type = Category.find(category_id).category_type
    return if current_types == [ new_type ]

    raise Api::BadRequest.new(CROSS_TYPE_MESSAGE, errors: { category_id: CROSS_TYPE_MESSAGE })
  end
end
