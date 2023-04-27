git pull
git add *
git commit -m 'slow is fast'
git push
# https://docs.compound.finance/v2/ctokens/ 
# 极其牛逼的资料

<<COMMENT
Compound 中每增加一个借贷市场（即资金池）的时候，都需要部署几个合约：
JumpRateModelV2：利率模型合约
CErc20Delegate：cToken逻辑合约
CErc20Delegator：cToken代理合约
COMMENT