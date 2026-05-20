public with sharing class CheckCaseStatusBot {
    public class CaseOutput{
        @InvocableVariable(required=true)
        public String CaseStatus;
    }
    
    Public class CaseInput{
        @InvocableVariable(required=true)
        public String CaseNumber;
    }
    
    @InvocableMethod(label='Check Case Status')
    public static List<CaseOutput> getCaseStatus(List<CaseInput> caseInputs){
        Set<String> caseNumbers = new Set<String>();
        
        //Get the order numbers from the input
        for(CaseInput caseInp : caseInputs){
            caseNumbers.add(caseInp.CaseNumber);
        }
        
        //Get the order objects from the set of order numbers
        List<case> cases =
            [SELECT Subject, Id, CaseNumber, Status FROM case where CaseNumber in :caseNumbers];
        
        //Create a map of order numbers and order status values
        Map<String, String> mapNameStatus = new Map<String, String>();
        if(cases.size() > 0){
            for (case vCase : cases){
                mapNameStatus.put(vCase.CaseNumber, vCase.Status);
            }
        }
        
        //Build a list of order status values for the output
        List<CaseOutput> caseOutputs = new List<CaseOutput>();
        for(CaseInput caseInput : caseInputs){
            CaseOutput caseOutput = new CaseOutput();
            
            //Do we have a status for this order number?
            if(mapNameStatus.containsKey(caseInput.CaseNumber)){
                //If not, then add the status value
                caseOutput.CaseStatus = mapNameStatus.get(caseInput.CaseNumber);
            }
            else{
                //If not, hen add an unknown status value
                caseOutput.CaseStatus = 'Case not found';
            }
            caseOutputs.add(caseOutput);
        }
        return caseOutputs;
    }
}