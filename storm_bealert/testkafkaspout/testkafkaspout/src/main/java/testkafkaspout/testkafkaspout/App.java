package testkafkaspout.testkafkaspout;

/**
 * Hello world!
 *
 */

import backtype.storm.Config;
import backtype.storm.StormSubmitter;
import backtype.storm.topology.TopologyBuilder;

import storm.kafka.KafkaSpout;
import storm.kafka.SpoutConfig;
import storm.kafka.ZkHosts;

public class App 
{
    public static void main( String[] args )
    {
        SpoutConfig spc = new SpoutConfig(new ZkHosts("localhost:2181"), "osix2" , "/tmp", "kafkaspout");
        KafkaSpout kfksp = new KafkaSpout(spc);
        System.out.println(" Kafka Spout is created as "+kfksp.toString());
        TopologyBuilder tb = new TopologyBuilder();
        tb.setSpout("kafkatestspout", kfksp);
        KafkaBolt bolt = new KafkaBolt();
        tb.setBolt("kafkatestbolt", bolt).shuffleGrouping("kafkatestspout");
        Config conf =new Config();
        try{
        	StormSubmitter.submitTopology("storm_topo_test", conf, tb.createTopology());
        }catch(Exception e){
        	System.out.println("Got error while submitting topology "+e.getMessage());
        }
    }
}
