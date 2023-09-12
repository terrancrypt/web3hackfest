# TC Protocol

Sorry for any Vietnamese in the code, or anywhere you see in my project (if you don't understand).

Winnning Project In Defi Track Of [Ref Finnane](https://www.ref.finance/) At [Web3 Hackfest 2023](https://devfolio.co/projects/tc-protocol-e5f8).
The project's interface has been upgraded, all functions of the smart contract remain the same as when submitting the project to the hackathon.

Old interface: [https://web3hackfest.vercel.app](https://tcprotocol.vercel.app/).

Old github repo: [here](https://github.com/terrancrypt/web3hackfest).

Link to the project at Web3 Hackfest [here](https://devfolio.co/projects/tc-protocol-e5f8).

New interface (with multi-chain upgrades): [https://tcprotocol.vercel.app/](https://tcprotocol.vercel.app/).
New repo: [https://github.com/terrancrypt/tcprotocol](https://github.com/terrancrypt/tcprotocol)

# About
This project is built to create a stable coin based on the price of dollars. Users can use their collateral (WETH or WBTC or more) to borrow (or mint) the tcUSD stable coin with no borrow fees.

All ideas and suggestions provided are solely based on the inference, reference, and input of a single individual who is part of this project. They have not been audited or consulted with industry experts regarding the protocol and feasibility of the project.

- [Technology stacks](#technology-stacks)
- [Benefit](#benefit)
  - [What will the project owner benefit?](#what-will-the-project-owner-benefit)
  - [What will users benefit?](#what-will-users-benefit)
- [Liquidators](#liquidators)
- [Health Factor](#health-factor)
- [The idea has not been implemented yet](#the-idea-has-not-been-implemented-yet)
  - [DAO](#dao)
  - [Floating liquidation bonus](#floating-liquidation-bonus)
  - [Backend](#backend)
  - [Automatic liquidation bot](#automatic-liquidation-bot)

# Technology stacks
- Front End: [NextJS](https://nextjs.org/)
- Smart contract: [Foundry](https://getfoundry.sh/)

# Benefit
## What will the project owner benefit?
In the initial stages, the project might not have introduced a Decentralized Autonomous Organization (DAO) to ensure revenue. It could compete by refraining from imposing fees for borrowing tokens and providing easy access. The process of minting tokens and reclaiming collateral tokens should be straightforward. In this scenario, the project owner would also act as the liquidator within the protocol.

If there's available capital, the project could establish liquid token pairs with reputable projects on decentralized exchanges (DEXs). This would add value to stablecoins and generate transaction fees. Alternatively, if feasible, the project could integrate with Automated Market Maker (AMM) projects or launchpads on new blockchain networks. This diversification could involve deployment on multiple chains.

The primary objective remains to maximize value for users who hold tcUSD (a stablecoin or token within the project ecosystem). As the project scales, it's crucial to enhance protocol security by deploying on established platforms, conducting comprehensive audits, and extending testing periods.

The above strategy aims to ensure the project's success and the security of its users while exploring opportunities for growth and expansion across various blockchain networks and related projects.

## What will users benefit?
The primary incentive for users to utilize tcUSD is the ability to freely borrow (or mint) tcUSD for short-term investments in tokens that are projected to have short-term growth potential. Users would only be exposed to the risk of liquidation if the collateral's price becomes overvalued.

To enhance user engagement, it's crucial to increase tcUSD's visibility and convenience. This involves expanding its presence across various chains and protocols. However, this objective presents a significant challenge for the project's developers.

As the project progresses, with more assets being used as collateral and more tcUSD being minted, the utility of tcUSD can grow across multiple platforms. This expansion would lead to increased usage and success for the project as a whole.

# Liquidators
The role of the liquidator holds significant importance within the entire project framework. Liquidators are responsible for liquidating overcollateralized positions, thereby contributing to the overall safety of the project. In return for their efforts, liquidators receive a 10% bonus based on the total value of the liquidation, represented by the tcUSD they burn. The remaining portion of the liquidation value is retained by the project owner.

The liquidation process within the protocol can be categorized into two main types: partial liquidation and full liquidation.

1. Partial Liquidation: This mechanism enables liquidators with insufficient tcUSD balance to cover the entire debt of a loan position. Partial liquidation is essential, particularly for handling large positions in the protocol. If only full liquidation were possible, the protocol might face challenges, especially when the collateral's value decreases rapidly. This approach allows the protocol to remain functional despite market fluctuations.

2. Full Liquidation: In the case of a full liquidation, the liquidator liquidates the entire position, similar to partial liquidation. However, in this scenario, the position is completely closed, and it ceases to exist as a partial liquidation would.

Another notable aspect is that the partial liquidation process facilitates multiple liquidators to collaborate in liquidating a substantial position. This collaborative approach enhances the security of the protocol by ensuring that even large positions can be efficiently managed and liquidated, preventing the protocol from being compromised.

Incorporating both partial and full liquidation mechanisms along with the involvement of multiple liquidators in handling larger positions collectively contributes to the robustness and safety of the protocol.

# Health Factor
The health factor index is referenced from AAVE. You can see it [here](https://docs.aave.com/risk/asset-risk/risk-parameters).

# The idea has not been implemented yet
## DAO
Establishing a Decentralized Autonomous Organization (DAO) is indeed a crucial feature, even though you may not have the time to develop it immediately. Before setting up the DAO, it's important to have the project's token in place. Staking this token should enable participants to receive governance tokens, granting them the ability to take part in the voting process.

The DAO can play a significant role by allowing token holders to vote on various proposed features. Some potential features for voting could include:

1. Adjusting Mortgage Rates: Token holders could participate in voting to change the mortgage rates. This flexibility can help the protocol adapt to changing market conditions and optimize the platform's stability.

2. Liquidator Voting: Given the critical role of liquidators in the project's safety, voting for liquidators is a valuable capability. If you've designed the contract to delegate liquidation powers to specific individuals, the DAO can be utilized to choose, confirm, or even remove liquidators if necessary.

3. Collateral Addition: Token holders could vote on adding new types of collateral to the protocol. This expansion can enhance the diversity and robustness of the ecosystem, potentially attracting more users.

By enabling these voting mechanisms, the DAO ensures that the community has a say in shaping the project's future and governance. While building the DAO might not be immediate, having the groundwork for token issuance and staking can lay the foundation for its eventual implementation. This phased approach allows you to first establish the protocol's functionality and user base while planning for the integration of decentralized governance in the future.
## Floating liquidation bonus
Floating liquidation bonus

Calculate the health factor of the value pool, and then use that to adjust the liquidation bonus.

If the health factor is high, the liquidation bonus will decrease.
If the health factor is low, the liquidation bonus will increase.

The increase should not exceed 20%, and the decrease should not exceed 5%.

## Backend
It would be great if I could integrate more backend into the project. This will reduce unnecessary requests for the EVM blockchain side. Additionally, the backend will also store the cached records to further reduce the load on the requests. I had planned to do it with NestJS (NodeJS framework), but time didn't allow.

## Automatic liquidation bot
The auto-liquidation bot is a core part of maintaining the protocol, protecting it from fluctuations in collateral prices.

In this respect, I am limited because I do not know how to write Python.

The Liquidation bot is open-source software that assists project owners and liquidators who wish to engage with the project. It allows them to install and operate bots that automatically monitor positions with a health factor below 1 and subsequently initiate liquidations. That's the basic idea.

Furthermore, the liquidation bot has the capability to autonomously connect to decentralized exchanges through smart contracts. This enables it to promptly convert the acquired collateral and bonuses into different stablecoins. This feature is implemented to mitigate risks and safeguard assets during market downturns.
