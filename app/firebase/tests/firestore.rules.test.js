import { readFileSync } from 'node:fs';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  where,
  serverTimestamp,
  setDoc,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';
import { afterAll, beforeAll, beforeEach, describe, it } from 'vitest';

// テスト用のダミーアカウント（実在しないアドレス）
// ALICE は開発者、BOB は一般の家族
const ALICE = { uid: 'alice', email: 'allowed@example.com' };
const BOB = { uid: 'bob', email: 'allowed2@example.com' };
const MALLORY = { uid: 'mallory', email: 'denied@example.com' };

let testEnv;

function dbOf(user) {
  return testEnv
    .authenticatedContext(user.uid, { email: user.email, email_verified: true })
    .firestore();
}

function newItem(user, overrides = {}) {
  return {
    name: 'トイレットペーパー',
    categoryId: 'water',
    status: 'low',
    memo: '',
    purchase: null,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    updatedByUid: user.uid,
    updatedByName: user.uid,
    ...overrides,
  };
}

function newFeedback(user, overrides = {}) {
  return {
    type: 'request',
    body: '並び順を変えたい',
    appVersion: '1.0.0+1',
    byUid: user.uid,
    byName: user.uid,
    createdAt: serverTimestamp(),
    status: 'open',
    devMemo: '',
    ...overrides,
  };
}

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-living-manager',
    firestore: { rules: readFileSync('firestore.rules', 'utf8') },
  });
});

afterAll(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'allowedUsers', ALICE.email), { memo: 'test', admin: true });
    await setDoc(doc(db, 'allowedUsers', BOB.email), { memo: 'test' });
    await setDoc(doc(db, 'categories', 'other'), { name: 'その他', order: 9999 });
    await setDoc(doc(db, 'feedback', 'fromBob'), newFeedback(BOB, { createdAt: new Date() }));
    await setDoc(doc(db, 'items', 'sample'), {
      ...newItem(ALICE),
      createdAt: new Date(),
      updatedAt: new Date(),
    });
  });
});

describe('許可リスト', () => {
  it('未ログインのユーザーは読み取りできない', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, 'items/sample')));
  });

  it('許可されていないユーザーは読み取りできない', async () => {
    await assertFails(getDoc(doc(dbOf(MALLORY), 'items/sample')));
  });

  it('許可されたユーザーは読み取りできる', async () => {
    await assertSucceeds(getDoc(doc(dbOf(ALICE), 'items/sample')));
  });

  it('一般の家族は自分の許可リストのドキュメントだけ確認できる', async () => {
    await assertSucceeds(getDoc(doc(dbOf(BOB), 'allowedUsers', BOB.email)));
    await assertSucceeds(getDoc(doc(dbOf(MALLORY), 'allowedUsers', MALLORY.email)));
    await assertFails(getDoc(doc(dbOf(BOB), 'allowedUsers', ALICE.email)));
    await assertFails(getDoc(doc(dbOf(MALLORY), 'allowedUsers', BOB.email)));
  });

  it('開発者は許可リストの一覧を見られる。一般の家族は見られない', async () => {
    await assertSucceeds(getDocs(collection(dbOf(ALICE), 'allowedUsers')));
    await assertSucceeds(getDoc(doc(dbOf(ALICE), 'allowedUsers', BOB.email)));
    await assertFails(getDocs(collection(dbOf(BOB), 'allowedUsers')));
  });

  it('開発者だけが許可リストに追加できる', async () => {
    const data = { memo: 'マロリー', admin: false, approvedAt: serverTimestamp() };
    await assertFails(setDoc(doc(dbOf(BOB), 'allowedUsers', MALLORY.email), data));
    await assertFails(setDoc(doc(dbOf(MALLORY), 'allowedUsers', MALLORY.email), data));
    await assertSucceeds(setDoc(doc(dbOf(ALICE), 'allowedUsers', MALLORY.email), data));
  });

  it('許可リストへの追加は決まった形だけ。大文字のメールアドレスは不可', async () => {
    const db = dbOf(ALICE);
    const ok = { memo: '', admin: true, approvedAt: serverTimestamp() };
    await assertFails(setDoc(doc(db, 'allowedUsers', 'New@example.com'), ok));
    await assertFails(setDoc(doc(db, 'allowedUsers', 'a@example.com'), { ...ok, admin: 'yes' }));
    await assertFails(setDoc(doc(db, 'allowedUsers', 'b@example.com'), { ...ok, memo: 'x'.repeat(51) }));
    await assertFails(setDoc(doc(db, 'allowedUsers', 'c@example.com'), { ...ok, extra: 1 }));
  });

  it('許可リストの変更・削除はアプリからできない', async () => {
    await assertFails(updateDoc(doc(dbOf(ALICE), 'allowedUsers', BOB.email), { memo: 'x' }));
    await assertFails(deleteDoc(doc(dbOf(ALICE), 'allowedUsers', BOB.email)));
  });
});

describe('accessRequests', () => {
  function newRequest(user, overrides = {}) {
    return { uid: user.uid, displayName: 'マロリー', requestedAt: serverTimestamp(), ...overrides };
  }

  it('許可されていないアカウントは自分の依頼を作れる', async () => {
    const db = dbOf(MALLORY);
    await assertSucceeds(setDoc(doc(db, 'accessRequests', MALLORY.email), newRequest(MALLORY)));
    await assertSucceeds(getDoc(doc(db, 'accessRequests', MALLORY.email)));
  });

  it('他人の依頼は作れない・見られない', async () => {
    const db = dbOf(MALLORY);
    await assertFails(setDoc(doc(db, 'accessRequests', 'other@example.com'), newRequest(MALLORY)));
    await assertFails(setDoc(doc(db, 'accessRequests', MALLORY.email), newRequest(BOB)));
    await assertFails(getDoc(doc(db, 'accessRequests', 'other@example.com')));
    await assertFails(getDocs(collection(db, 'accessRequests')));
  });

  it('許可済みのアカウントは依頼を作れない', async () => {
    await assertFails(setDoc(doc(dbOf(BOB), 'accessRequests', BOB.email), newRequest(BOB)));
  });

  it('依頼は決まった形だけ。作り直し（上書き）はできない', async () => {
    const db = dbOf(MALLORY);
    const ref = doc(db, 'accessRequests', MALLORY.email);
    await assertFails(setDoc(ref, newRequest(MALLORY, { displayName: 'x'.repeat(51) })));
    await assertFails(setDoc(ref, newRequest(MALLORY, { admin: true })));
    await assertSucceeds(setDoc(ref, newRequest(MALLORY)));
    await assertFails(setDoc(ref, newRequest(MALLORY)));
    await assertFails(deleteDoc(ref));
  });

  it('開発者は依頼の一覧を見て、承認（追加と削除を同時に）・却下できる', async () => {
    await assertSucceeds(setDoc(doc(dbOf(MALLORY), 'accessRequests', MALLORY.email), newRequest(MALLORY)));
    await assertFails(getDocs(collection(dbOf(BOB), 'accessRequests')));
    await assertFails(deleteDoc(doc(dbOf(BOB), 'accessRequests', MALLORY.email)));

    const db = dbOf(ALICE);
    await assertSucceeds(getDocs(collection(db, 'accessRequests')));
    const batch = writeBatch(db);
    batch.set(doc(db, 'allowedUsers', MALLORY.email), { memo: 'マロリー', admin: false, approvedAt: serverTimestamp() });
    batch.delete(doc(db, 'accessRequests', MALLORY.email));
    await assertSucceeds(batch.commit());
    await assertSucceeds(getDoc(doc(dbOf(MALLORY), 'items/sample')));
  });
});

describe('users', () => {
  it('自分のドキュメントだけ作成できる', async () => {
    const data = { displayName: 'アリス', createdAt: serverTimestamp(), updatedAt: serverTimestamp() };
    await assertSucceeds(setDoc(doc(dbOf(ALICE), 'users', ALICE.uid), data));
    await assertFails(setDoc(doc(dbOf(ALICE), 'users', BOB.uid), data));
  });

  it('表示名は 20 文字まで', async () => {
    const data = { displayName: 'あ'.repeat(21), createdAt: serverTimestamp(), updatedAt: serverTimestamp() };
    await assertFails(setDoc(doc(dbOf(ALICE), 'users', ALICE.uid), data));
  });

  it('自分の並び順は保存できるが、他人の並び順は変えられない', async () => {
    const data = { displayName: 'アリス', createdAt: serverTimestamp(), updatedAt: serverTimestamp() };
    await assertSucceeds(setDoc(doc(dbOf(ALICE), 'users', ALICE.uid), data));
    await assertSucceeds(setDoc(doc(dbOf(BOB), 'users', BOB.uid), { ...data, displayName: 'ボブ' }));
    const order = { 'itemOrder.water': ['sample'], updatedAt: serverTimestamp() };
    await assertSucceeds(updateDoc(doc(dbOf(ALICE), 'users', ALICE.uid), order));
    await assertFails(updateDoc(doc(dbOf(ALICE), 'users', BOB.uid), order));
  });

  it('並び順はマップでなければ保存できない', async () => {
    const data = { displayName: 'アリス', itemOrder: 'x', createdAt: serverTimestamp(), updatedAt: serverTimestamp() };
    await assertFails(setDoc(doc(dbOf(ALICE), 'users', ALICE.uid), data));
  });

  it('閉じているカテゴリは自分のドキュメントにだけ保存できる', async () => {
    const data = { displayName: 'アリス', createdAt: serverTimestamp(), updatedAt: serverTimestamp() };
    await assertSucceeds(setDoc(doc(dbOf(ALICE), 'users', ALICE.uid), data));
    await assertSucceeds(setDoc(doc(dbOf(BOB), 'users', BOB.uid), { ...data, displayName: 'ボブ' }));
    const hidden = { hiddenCategories: ['water'], updatedAt: serverTimestamp() };
    await assertSucceeds(updateDoc(doc(dbOf(ALICE), 'users', ALICE.uid), hidden));
    await assertFails(updateDoc(doc(dbOf(ALICE), 'users', BOB.uid), hidden));
  });

  it('閉じているカテゴリは配列でなければ保存できない', async () => {
    const data = { displayName: 'アリス', hiddenCategories: 'water', createdAt: serverTimestamp(), updatedAt: serverTimestamp() };
    await assertFails(setDoc(doc(dbOf(ALICE), 'users', ALICE.uid), data));
  });
});

describe('categories', () => {
  it('「その他」は削除できない', async () => {
    await assertFails(deleteDoc(doc(dbOf(ALICE), 'categories', 'other')));
  });

  it('カテゴリ削除時に、更新者を変えずにアイテムを「その他」へ移せる', async () => {
    await assertSucceeds(updateDoc(doc(dbOf(BOB), 'items', 'sample'), { categoryId: 'other' }));
  });
});

describe('items', () => {
  it('正しいデータなら追加できる', async () => {
    await assertSucceeds(setDoc(doc(dbOf(ALICE), 'items', 'new'), newItem(ALICE)));
  });

  it('不正なステータスは保存できない', async () => {
    await assertFails(setDoc(doc(dbOf(ALICE), 'items', 'new'), newItem(ALICE, { status: 'unknown' })));
  });

  it('他人を更新者にして保存できない', async () => {
    await assertFails(setDoc(doc(dbOf(ALICE), 'items', 'new'), newItem(BOB)));
  });

  it('「十分」のまま担当者を持てない', async () => {
    const purchase = { state: 'planned', byUid: ALICE.uid, byName: 'アリス', at: serverTimestamp() };
    await assertFails(
      setDoc(doc(dbOf(ALICE), 'items', 'new'), newItem(ALICE, { status: 'sufficient', purchase })),
    );
  });

  it('担当は自分にできるが、他人にはできない', async () => {
    const ref = doc(dbOf(BOB), 'items', 'sample');
    const mine = { state: 'planned', byUid: BOB.uid, byName: 'ボブ', at: serverTimestamp() };
    const others = { state: 'planned', byUid: ALICE.uid, byName: 'アリス', at: serverTimestamp() };
    await assertSucceeds(updateDoc(ref, { purchase: mine }));
    await assertFails(updateDoc(ref, { purchase: others }));
  });

  it('担当だけを変えるときは更新者を変えなくてよい', async () => {
    const purchase = { state: 'in_cart', byUid: BOB.uid, byName: 'ボブ', at: serverTimestamp() };
    await assertSucceeds(updateDoc(doc(dbOf(BOB), 'items', 'sample'), { purchase }));
  });
});

describe('items（バーコード）', () => {
  it('バーコードは 10 個まで、配列でなければ保存できない', async () => {
    const ref = doc(dbOf(ALICE), 'items', 'sample');
    const codes = (n) => Array.from({ length: n }, (_, i) => `490000000000${i}`);
    await assertSucceeds(updateDoc(ref, { barcodes: codes(10) }));
    await assertFails(updateDoc(ref, { barcodes: codes(11) }));
    await assertFails(updateDoc(ref, { barcodes: '4901234567894' }));
  });

  it('バーコードだけを変えるときは更新者を変えなくてよい', async () => {
    await assertSucceeds(updateDoc(doc(dbOf(BOB), 'items', 'sample'), { barcodes: ['4901234567894'] }));
  });
});

describe('purchaseHistory', () => {
  function newRecord(user, overrides = {}) {
    return {
      itemId: 'sample',
      itemName: 'トイレットペーパー',
      byUid: user.uid,
      byName: user.uid,
      purchasedAt: serverTimestamp(),
      ...overrides,
    };
  }

  const DAY = 24 * 60 * 60 * 1000;

  async function seedRecord(id, user, purchasedAt) {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'purchaseHistory', id), newRecord(user, { purchasedAt }));
    });
  }

  it('家族は自分の名義で記録を追加でき、全員が読める', async () => {
    await assertSucceeds(setDoc(doc(dbOf(BOB), 'purchaseHistory', 'r1'), newRecord(BOB)));
    await assertSucceeds(getDocs(collection(dbOf(ALICE), 'purchaseHistory')));
    await assertFails(getDocs(collection(dbOf(MALLORY), 'purchaseHistory')));
    await assertFails(setDoc(doc(dbOf(MALLORY), 'purchaseHistory', 'r2'), newRecord(MALLORY)));
  });

  it('他人の名義・決まった形以外・サーバー時刻以外の日時では追加できない', async () => {
    const db = dbOf(BOB);
    await assertFails(setDoc(doc(db, 'purchaseHistory', 'r1'), newRecord(ALICE)));
    await assertFails(setDoc(doc(db, 'purchaseHistory', 'r2'), newRecord(BOB, { extra: 1 })));
    await assertFails(setDoc(doc(db, 'purchaseHistory', 'r3'), newRecord(BOB, { itemName: '' })));
    await assertFails(setDoc(doc(db, 'purchaseHistory', 'r4'), newRecord(BOB, { purchasedAt: new Date(Date.now() - DAY) })));
  });

  it('記録は変更できない', async () => {
    await seedRecord('r1', BOB, new Date());
    await assertFails(updateDoc(doc(dbOf(BOB), 'purchaseHistory', 'r1'), { itemName: '書き換え' }));
  });

  it('自分の記録は消せる（元に戻す）が、1 年以内の他人の記録は消せない', async () => {
    await seedRecord('mine', BOB, new Date());
    await seedRecord('alices', ALICE, new Date(Date.now() - 300 * DAY));
    await assertSucceeds(deleteDoc(doc(dbOf(BOB), 'purchaseHistory', 'mine')));
    await assertFails(deleteDoc(doc(dbOf(BOB), 'purchaseHistory', 'alices')));
  });

  it('1 年を過ぎた記録は、家族の誰でも消せる', async () => {
    await seedRecord('old', ALICE, new Date(Date.now() - 367 * DAY));
    await assertFails(deleteDoc(doc(dbOf(MALLORY), 'purchaseHistory', 'old')));
    await assertSucceeds(deleteDoc(doc(dbOf(BOB), 'purchaseHistory', 'old')));
  });

  it('購入完了は、アイテムの更新と記録の追加を 1 回のバッチでできる', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), 'items', 'sample'), {
        purchase: { state: 'in_cart', byUid: BOB.uid, byName: BOB.uid, at: new Date() },
      });
    });
    const db = dbOf(BOB);
    const batch = writeBatch(db);
    batch.update(doc(db, 'items', 'sample'), {
      status: 'sufficient',
      purchase: null,
      updatedAt: serverTimestamp(),
      updatedByUid: BOB.uid,
      updatedByName: BOB.uid,
    });
    batch.set(doc(db, 'purchaseHistory', 'r1'), newRecord(BOB));
    await assertSucceeds(batch.commit());
  });
});

describe('feedback', () => {
  it('家族は改善意見を送れる', async () => {
    await assertSucceeds(setDoc(doc(dbOf(BOB), 'feedback', 'new'), newFeedback(BOB)));
  });

  it('許可されていないユーザーは送れない', async () => {
    await assertFails(setDoc(doc(dbOf(MALLORY), 'feedback', 'new'), newFeedback(MALLORY)));
  });

  it('送るときに状態やメモを指定できない・他人の名義にできない', async () => {
    const db = dbOf(BOB);
    await assertFails(setDoc(doc(db, 'feedback', 'a'), newFeedback(BOB, { status: 'done' })));
    await assertFails(setDoc(doc(db, 'feedback', 'b'), newFeedback(BOB, { devMemo: 'x' })));
    await assertFails(setDoc(doc(db, 'feedback', 'c'), newFeedback(ALICE)));
    await assertFails(setDoc(doc(db, 'feedback', 'd'), newFeedback(BOB, { body: '' })));
  });

  it('一般の家族は自分の意見だけ読める', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'feedback', 'fromAlice'), newFeedback(ALICE, { createdAt: new Date() }));
    });
    const db = dbOf(BOB);
    await assertSucceeds(getDoc(doc(db, 'feedback', 'fromBob')));
    await assertSucceeds(getDocs(query(collection(db, 'feedback'), where('byUid', '==', BOB.uid))));
    await assertFails(getDoc(doc(db, 'feedback', 'fromAlice')));
    await assertFails(getDocs(collection(db, 'feedback')));
  });

  it('開発者はすべて読める', async () => {
    await assertSucceeds(getDocs(collection(dbOf(ALICE), 'feedback')));
  });

  it('状態とメモを変えられるのは開発者だけ', async () => {
    const change = { status: 'in_progress', devMemo: '対応します', statusUpdatedAt: serverTimestamp() };
    await assertFails(updateDoc(doc(dbOf(BOB), 'feedback', 'fromBob'), change));
    await assertSucceeds(updateDoc(doc(dbOf(ALICE), 'feedback', 'fromBob'), change));
  });

  it('開発者でも本文は変えられず、不正な状態にもできない', async () => {
    const ref = doc(dbOf(ALICE), 'feedback', 'fromBob');
    await assertFails(updateDoc(ref, { body: '書き換え' }));
    await assertFails(updateDoc(ref, { status: 'unknown' }));
  });

  it('削除できるのは開発者だけ', async () => {
    await assertFails(deleteDoc(doc(dbOf(BOB), 'feedback', 'fromBob')));
    await assertSucceeds(deleteDoc(doc(dbOf(ALICE), 'feedback', 'fromBob')));
  });
});
