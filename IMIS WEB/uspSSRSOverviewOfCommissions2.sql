
IF NOT OBJECT_ID('uspSSRSOverviewOfCommissions') IS NULL
DROP PROCEDURE uspSSRSOverviewOfCommissions

GO
CREATE PROCEDURE [dbo].[uspSSRSOverviewOfCommissions]
(
    @Month INT,
    @Year INT, 
	@Mode INT=1,
	@OfficerId INT =NULL,
    @LocationId INT=NULL, 
	@ProdId INT = NULL,
	@PayerId INT = NULL,
	@ReportingId INT = NULL,
	@CommissionRate DECIMAL(18,2) = NULL,
	@ErrorMessage NVARCHAR(200) = N'' OUTPUT
)
AS
  BEGIN

   --   ReportType
	  --1 = OverviewCommissions report
	  --2 = MatchingFund report
	  declare @StartMatchDate AS DATE  = null
	  declare @EndMatchDate AS DATE  = null
	  DECLARE @FirstDay DATE = CAST(@Year AS VARCHAR(4)) + '-' + CAST(@Month AS VARCHAR(2)) + '-01'; 
	  DECLARE @LastDay DATE = EOMONTH(CAST(@Year AS VARCHAR(4)) + '-' + CAST(@Month AS VARCHAR(2)) + '-01', 0)


		
      DECLARE @RecordFound INT = 0

	--Create new entries only if reportingId is not provided

	  IF @ReportingId IS NULL

        BEGIN

		BEGIN TRY
				BEGIN TRAN

			  
				
			    INSERT INTO tblReporting(ReportingDate,LocationId, ProdId, PayerId, StartDate, EndDate, RecordFound,OfficerID,ReportType)
			
				SELECT GETDATE(),ISNULL(@LocationId,0), ISNULL(@ProdId,0), @PayerId, @FirstDay, @LastDay, 0,@OfficerId,2;

				--Get the last inserted reporting Id
				SELECT @ReportingId =  SCOPE_IDENTITY();

				UPDATE tblPremium SET ReportingCommissionID = @ReportingId
				WHERE PremiumId IN (
                SELECT  Pr.PremiumId
				FROM tblPremium Pr 
				LEFT JOIN tblPolicy PL ON Pr.PolicyID = PL.PolicyID and pl.ValidityTo IS NULL
				LEFT JOIN tblPaymentDetails PD ON PD.PremiumID = Pr.PremiumId
				LEFT JOIN tblPayment PY ON PY.PaymentID = PD.PaymentID and  pD.ValidityTo IS NULL
				INNER JOIN tblProduct Prod ON PL.ProdID = Prod.ProdID AND PROD.ValidityTo IS NULL
				INNER JOIN tblFamilies F ON PL.FamilyID = F.FamilyID AND F.ValidityTo  IS NULL
				INNER JOIN tblVillages V ON V.VillageId = F.LocationId AND V.ValidityTo IS NULL
				INNER JOIN tblWards W ON W.WardId = V.WardId AND W.ValidityTo IS NULL
			    INNER JOIN tblDistricts D ON D.DistrictId = W.DistrictId AND D.ValidityTo IS NULL
				LEFT JOIN tblOfficer O ON O.LocationId = D.DistrictId AND O.ValidityTo IS NULL AND O.OfficerID = PL.OfficerID
				INNER JOIN tblInsuree Ins ON F.FamilyID = Ins.FamilyID  AND Ins.ValidityTo IS NULL AND ins.IsHead = 1
				LEFT OUTER JOIN tblPayer Payer ON Pr.PayerId = Payer.PayerID AND Payer.ValidityTo IS  NULL
				left join tblReporting ON PR.ReportingCommissionID =tblReporting.ReportingId AND tblReporting.ReportType=2

				WHERE Pr.ValidityTo IS NULL 
				AND PY.ValidityTo IS NULL
				
				AND (D.DistrictID = @LocationId OR @LocationId IS NULL)
				AND PayDate BETWEEN @FirstDay AND @LastDay
				AND (Prod.ProdID = @ProdId OR @ProdId IS NULL)
			    AND (O.OfficerID = @OfficerID OR @OfficerID  IS NULL)
				AND (Payer.PayerID = @PayerID OR @PayerID IS NULL)
				and (PY.MatchedDate BETWEEN @FirstDay AND @LastDay OR @Mode = 0)
				AND (Pr.Amount >= PD.Amount OR @Mode=0)
				AND Pr.ReportingCommissionID IS NULL
				AND PR.PayType <> N'F'
				)

				SELECT @RecordFound = @@ROWCOUNT;

				UPDATE tblReporting SET RecordFound = @RecordFound WHERE ReportingId = @ReportingId;

			COMMIT TRAN;
		END TRY
		BEGIN CATCH
			SELECT @ErrorMessage = ERROR_MESSAGE();
			ROLLBACK;
			RETURN -1
		END CATCH
	  END
				        
				SELECT Pr.PremiumId,Prod.ProductCode,Prod.ProdID,Prod.ProductName,prod.ProductCode +' ' + prod.ProductName Product,  PL.PolicyID, F.FamilyID, D.DistrictName,o.OfficerID , Ins.CHFID, Ins.LastName + ' ' + Ins.OtherNames InsName,O.Code + ' ' + O.LastName Officer,
				Ins.DOB, Ins.IsHead, PL.EnrollDate, Pr.Paydate, Pr.Receipt, Pr.Amount as TotlaPrescribedContribution, PD.Amount TotlActualPayment, Payer.PayerName,PY.PaymentDate,(@CommissionRate / 100) AS CommissionRate,PY.ExpectedAmount PaymentAmount
				FROM tblPremium Pr 
				LEFT JOIN tblPolicy PL ON Pr.PolicyID = PL.PolicyID and pl.ValidityTo IS NULL
				LEFT JOIN tblPaymentDetails PD ON PD.PremiumID = Pr.PremiumId
				LEFT JOIN tblPayment PY ON PY.PaymentID = PD.PaymentID and  pD.ValidityTo IS NULL
				INNER JOIN tblProduct Prod ON PL.ProdID = Prod.ProdID AND PROD.ValidityTo IS NULL
				INNER JOIN tblFamilies F ON PL.FamilyID = F.FamilyID AND F.ValidityTo  IS NULL
				INNER JOIN tblVillages V ON V.VillageId = F.LocationId AND V.ValidityTo IS NULL
				INNER JOIN tblWards W ON W.WardId = V.WardId AND W.ValidityTo IS NULL
			    INNER JOIN tblDistricts D ON D.DistrictId = W.DistrictId AND D.ValidityTo IS NULL
				LEFT JOIN tblOfficer O ON O.LocationId = D.DistrictId AND O.ValidityTo IS NULL AND O.OfficerID = PL.OfficerID
				INNER JOIN tblInsuree Ins ON F.FamilyID = Ins.FamilyID  AND Ins.ValidityTo IS NULL AND ins.IsHead = 1
				LEFT OUTER JOIN tblPayer Payer ON Pr.PayerId = Payer.PayerID AND Payer.ValidityTo IS  NULL

				WHERE Pr.ReportingCommissionID =@ReportingId
				
			    SET @ErrorMessage = N''	
			    RETURN 0	

END
GO
