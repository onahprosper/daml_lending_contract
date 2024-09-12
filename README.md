
# Loan Repayment Workflow Documentation (Difficult)

## Task Overview

### Goal:
The core of this solution revolves around enforcing structure and compliance in the loan repayment process. By implementing both incremental disbursements and incremental repayments, I created a system that is flexible for borrowers yet ensures banks maintain control over loan distribution and repayment.

The DAML test scripts played a vital role in validating each step of this process, ensuring that the system behaves as expected under various conditions (e.g., valid repayments, invalid zero repayments, excessive repayments, etc.).

Overall, the design emphasizes clarity, control, and compliance, providing a robust framework for secure financial transactions.

### Key requirements included:

    •	Implementing a RepaymentRestriction to define the minimum repayment amount.
    •	Adding a Repay choice to the Loan contract, ensuring that repayments respect the minimum amount.
    •	The contract should update the total repaid amount and archive itself once fully repaid.

## Code Design and Approach

### System Architecture and Entities
![System Architecture](./Img/arch.png)
#### The main entities involved in this workflow are:

    •	Bank (Goldman Sachs): Approves loans, issues tokens, and manages disbursement.
    •	Borrower: Requests a loan, receives disbursements in stages, and is responsible for repayment.
    •	Central Bank: Enforces rules such as repayment restrictions and oversees loan limits.

#### Key templates:

    •	LoanLimit: Tracks the loan utilization and sets limits for each borrower.
    •	RepaymentRestriction: Defines the minimum repayment allowed for each borrower.
    •	Loan: Governs the loan lifecycle, including disbursement and repayment.
    •	Token: Represents the loan value in tokenized form (e.g., IOUs).

#### Test Scripts

The DAML test scripts were created to simulate the entire loan approval, disbursement, and repayment process. These tests are crucial to ensure that all requirements are met.

#### Test Workflow:

    1.	Loan Request: The borrower submits a loan request, and the bank approves it.
    2.	Disbursement: The bank partially disburses the loan, ensuring no disbursement exceeds the approved limit or falls below zero.
    3.	Repayment: The borrower repays the loan in increments, ensuring that each repayment meets the minimum requirement.
    4.	Contract Archival: Once the total repaid amount equals the loan amount, the contract is archived.


### Step 1: Clone the GitHub Repository

To start, clone the [project repository](https://github.com/OnahProsperity/Prosper_TakeHomeAssignment.git) from GitHub using the following command:
```sh
git clone <repository_url>
cd <repository_folder>****
```
### Step 2: Set Up the DAML Environment
Ensure you have the DAML SDK installed. You can download and install it from [here](https://docs.daml.com/getting-started/installation.html).

Once installed, run the following command to verify that DAML is set up correctly:

```sh
daml version
```
### Step 3: Build the Project
Navigate to the project directory and build the project using the following command:

```sh
daml build
```

### Step 4: Run the Tests
Execute the tests to ensure everything is working correctly:

```sh
daml test
```

## Task Breakdown & Implementation:

1. **RepaymentRestriction Template:**
   - [x] Implemented a `RepaymentRestriction` template that specifies the minimum amount required for each repayment.
   
2. **Loan Template:**
   - [x] **Repay Choice:**
     - Allows the borrower to make repayments on their loan.
   - [x] **Minimum Repayment Enforcement:**
     - Ensures that the repayment amount meets the minimum repayment requirement from the `RepaymentRestriction` contract.
   - [x] **Updating Total Repaid Amount:**
     - The `Repay` choice updates the total repaid amount after each repayment.
   - [x] **Token Transfer & Archive:**
     - The token contract associated with the repayment is updated.
     - Upon full repayment, the loan contract is archived, and the utilized loan amount is updated in the `LoanLimit` contract.
   
3. **LoanLimit Template:**
   - [x] **Update Utilized Loan Amount:**
     - A choice `UpdateUtilizedAmount` is implemented to update the utilized loan amount whenever there is a repayment or disbursement.
   
4. **Test Scripts:**
   - **Test for Full Disbursement & Repayment:**
     - [x] Tested successful full disbursement and repayment workflow, covering the following steps:
       - [x] Loan request approval.
       - [x] Disbursement of the full loan amount.
       - [x] Repayment of the full loan amount.
       - [x] Archiving the loan contract upon full repayment.
       - [x] Updating the utilized loan amount in the `LoanLimit` contract.
  
   - **Test for Partial Disbursement & Repayment:**
     - [x] Tested partial disbursement and repayment workflow, covering:
       - [x] Partial disbursement of the loan amount in multiple stages.
       - [x] Incremental repayment of the loan in multiple stages.
       - [x] Correct updating of the total repaid amount and remaining amount.
       - [x] Proper handling of minimum repayment restrictions.

## Detailed Breakdown of Test Coverage:

### 1. Full Disbursement & Repayment Test (`testSuccessfulDisburse`)
   - **Loan Request Validation**: 
     - Verifies the borrower and bank's involvement in the loan request and checks the requested loan amount.
   - **Disbursement Tests**:
     - Ensures that attempts to disburse zero or negative amounts fail.
     - Prevents disbursement beyond the borrower's loan limit.
     - Successfully disburses the full amount when all checks are passed.
    ![Loan Test Result](./Img/Loan.png)
   - **Repayment Tests**:
     - Validates full repayment and ensures that the total repaid amount is updated correctly.
     - Verifies that the loan contract is archived upon full repayment and that the `LoanLimit` is updated.
   ![Loan Test Result](./Img/LoanRequest.png)
   ![Loan Test Result](./Img/LoanLimit.png)
### 2. Partial Disbursement & Repayment Test (`testPartialDisburseRepay`)
   - **Loan Request Validation**: 
     - Same as the full disbursement test.
    ![Loan Test Result](./Img/RepaymentRestriction.png)
   - **Partial Disbursement Tests**:
     - Verifies correct handling of partial disbursements in multiple stages.
     - Ensures that the total disbursed amount is updated correctly after each disbursement.
   - **Partial Repayment Tests**:
     - Validates incremental repayments.
     - Ensures that the total repaid amount is updated correctly after each repayment.
     - Checks that the repayment adheres to the minimum repayment restrictions defined in the `RepaymentRestriction` contract.
![Loan Test Result](./Img/Token.png)
![Loan Test Result](./Img/TokenTransfer.png)

## Conclusion:

All functionality has been implemented and tested to meet the task's requirements. The system now supports both full and partial loan disbursements and repayments while enforcing repayment restrictions. The tests confirm that the system behaves as expected, with proper updates to loan amounts, token handling, and loan contract archiving.

