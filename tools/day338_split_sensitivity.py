"""Is m4_vocal_stress_en_38's 0.8321 a real number or a lucky split?

m5's shipped 0.7988 turned out to be the best of six held-out triples
(mean 0.6314, sd 0.1100, min 0.5060). The English model was reported from a
single split by the same method, so it owes the same check.
"""
import numpy as np, tensorflow as tf
from sklearn.metrics import roc_auc_score
d=np.load("yin_lite/yin_lite_feats.npz",allow_pickle=True)
X,y,spk=d["X"],d["y"],np.array([str(s) for s in d["spk"]])
def auc_for(held, cols):
    te=np.array([s in held for s in spk])
    Xs=X[:,cols]; mu,sd=Xs[~te].mean(0),Xs[~te].std(0)+1e-8
    Xn=((Xs-mu)/sd).astype("float32"); a=[]
    for s in (0,1):
        tf.keras.utils.set_random_seed(s)
        m=tf.keras.Sequential([tf.keras.layers.Input((len(cols),)),
            tf.keras.layers.Dense(64,activation="relu"),tf.keras.layers.Dropout(0.3),
            tf.keras.layers.Dense(32,activation="relu"),tf.keras.layers.Dense(1,activation="sigmoid")])
        m.compile(optimizer=tf.keras.optimizers.Adam(1e-3),loss="binary_crossentropy")
        m.fit(Xn[~te],y[~te],validation_split=0.1,epochs=60,batch_size=64,verbose=0,
              callbacks=[tf.keras.callbacks.EarlyStopping(monitor="val_loss",patience=8,restore_best_weights=True)])
        a.append(roc_auc_score(y[te],m.predict(Xn[te],verbose=0).ravel()))
    return float(np.mean(a))
APP28=list(range(7,33))+[36,37]
trials=[("0012","0016","0019"),("0011","0016","0017"),("0013","0014","0018"),
        ("0015","0017","0020"),("0011","0012","0013"),("0018","0019","0020")]
for tag,cols in (("38 (shipped m4 config)",list(range(38))),("28 (for comparison)",APP28)):
    res=[]
    print(f"\n{tag}:")
    for t in trials:
        a=auc_for(set(t),cols); res.append(a)
        mark=""
        if t==("0012","0016","0019"): mark="  <- my ablation split"
        if t==("0011","0016","0017"): mark="  <- the split 0.8321 was reported on"
        print(f"  held-out {list(t)}  AUC={a:.4f}{mark}")
    print(f"  mean {np.mean(res):.4f}  sd {np.std(res):.4f}  min {min(res):.4f}  max {max(res):.4f}")
