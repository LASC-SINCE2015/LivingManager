import { readFileSync } from 'node:fs';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  deleteDoc,
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  updateDoc,
} from 'firebase/firestore';
import { afterAll, beforeAll, beforeEach, describe, it } from 'vitest';

// テスト用のダミーアカウント（実在しないアドレス）
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
    await setDoc(doc(db, 'allowedUsers', ALICE.email), { memo: 'test' });
    await setDoc(doc(db, 'allowedUsers', BOB.email), { memo: 'test' });
    await setDoc(doc(db, 'categories', 'other'), { name: 'その他', order: 9999 });
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
