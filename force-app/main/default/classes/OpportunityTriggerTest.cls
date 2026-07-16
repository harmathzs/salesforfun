@IsTest
private class OpportunityTriggerTest {
  @IsTest
  static void testUpdate() {
      Map<String, Object> accContOppysMap = TestFactory.createCompleteTestSetup(1, 1, 1);
      Opportunity[] oppys = (List<Opportunity>) accContOppysMap.get('opportunities');
      for (Opportunity oppy: oppys) {
        oppy.StageName = 'Closed Won';
      }
      update oppys;
  }
  @IsTest
  static void testUndelete() {
    Map<String, Object> accContOppysMap = TestFactory.createCompleteTestSetup(1, 1, 1);
    Opportunity[] oppys = (List<Opportunity>) accContOppysMap.get('opportunities');

    delete oppys;
    undelete oppys;
  }
}
