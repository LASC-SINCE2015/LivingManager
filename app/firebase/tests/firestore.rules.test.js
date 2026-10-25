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

  it('自分の許可リストのドキュメントだけ確認できる', async () => {
    await assertSucceeds(getDoc(doc(dbOf(ALICE), 'allowedUsers', ALICE.email)));
    await assertSucceeds(getDoc(doc(dbOf(MALLORY), 'allowedUsers', MALLORY.email)));
    await assertFails(getDoc(doc(dbOf(ALICE), 'allowedUsers', BOB.email)));
  });

  it('許可リストはアプリから変更できない', async () => {
    await assertFails(setDoc(doc(dbOf(ALICE), 'allowedUsers', MALLORY.email), { memo: 'x' }));
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
