package testkafkaspout.testkafkaspout;

import java.io.PrintWriter;
import java.util.Map;

import backtype.storm.topology.OutputFieldsDeclarer;
import backtype.storm.task.TopologyContext;
import backtype.storm.topology.IRichBolt;
import backtype.storm.tuple.Fields;
import backtype.storm.tuple.Tuple;
import backtype.storm.task.OutputCollector;


public class KafkaBolt implements IRichBolt {
	private OutputCollector _collector;
	PrintWriter pr;
	@Override
	public void prepare(Map conf, TopologyContext context , OutputCollector collector){
		try{
			this.pr=new PrintWriter("/tmp/osixread.txt");
		}catch(Exception e){
			
		}
		this._collector=collector;
	}
	@Override
	public void execute(Tuple tuple){
    	byte[] bytes = tuple.getBinary(tuple.fieldIndex("bytes"));
    	try{
			String osixrec= new String (bytes,"UTF-8");
			this.pr.println(osixrec);
			this.pr.flush();
	        this._collector.ack(tuple);
    	}
    	catch(Exception e){
    		System.out.println("Got exception "+e.getMessage());
    	}
	}
	@Override
	public void declareOutputFields(OutputFieldsDeclarer declarer){
		declarer.declare(new Fields("string"));
	}
	public void cleanup() {
		// TODO Auto-generated method stub
		
	}
	public Map<String, Object> getComponentConfiguration() {
		// TODO Auto-generated method stub
		return null;
	}
}
